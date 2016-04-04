mkdirp = (require 'mkdirp')
path = (require 'path')
markdownpdf = (require 'markdown-pdf')
async = (require 'async')
fs = (require 'fs')
config = (require 'config')
appCfg = (config.get 'app')
request = (require 'request')
sanitize = (require "sanitize-filename")
{ expect, match, stub } = (require './helper')

key = appCfg.trello.key
token = appCfg.trello.token

TEST_BOARD_ID = "xxxxxxxxxxxxxxxxxxxxxxxx"
TEST_CARD_ID = "xxxxxxxxxxxxxxxxxxxxxxxx"

describe 'Playground', ->
	before ->
		urlGetToken = "https://trello.com/1/authorize?key=#{key}&name=TrelloBoardDownloader&expiration=never&response_type=token";

		(console.log "Please visit: #{urlGetToken}")

	describe 'Given token provided', ->

		describe 'When get boards', ->
			beforeEach (done) ->
				boardsUrl = "https://api.trello.com/1/members/me/boards?fields=name&key=#{key}&token=#{token}";
				(console.log { boardsUrl }, 'bingo')
				options =
					url: boardsUrl
					method: 'GET'
				request options, (@err, @res, @body) => done()

			it 'Should return a list of boards', ->
				(expect @err).to.not.defined
				(expect @res.statusCode).to.equal 200
				# (console.log body: @body, 'bingo')

		describe 'When get cards of board', ->
			beforeEach (done) ->
				boardUrl = "https://api.trello.com/1/boards/#{TEST_BOARD_ID}/cards?fields=name&key=#{key}&token=#{token}"
				(console.log { boardUrl }, 'bingo')
				options =
					url: boardUrl
					method: 'GET'
				request options, (@err, @res, @body) => done()

			it 'Should return a list of cards', ->
				if @err? then console.log { err: err }

				(expect @err).to.not.defined
				(expect @res.statusCode).to.equal 200
				# (console.log body: @body, 'bingo')

		describe.only 'When get lists of board', ->
			beforeEach (done) ->
				listsUrl = "https://api.trello.com/1/boards/#{TEST_BOARD_ID}/lists?cards=open&card_fields=name&fields=name&key=#{key}&token=#{token}"
				(console.log { listsUrl }, 'bingo')
				options =
					url: listsUrl
					method: 'GET'
				request options, (@err, @res, @body) => done()

			it 'Should return a list of lists', ->
				if @err? then console.log { err: err }
				(expect @err).to.not.defined
				(expect @res.statusCode).to.equal 200
				(console.log body: @body, 'bingo')

		describe 'When get card details', ->
			beforeEach (done) ->
				cardUrl = "https://api.trello.com/1/cards/#{TEST_CARD_ID}?fields=name,desc&key=#{key}&token=#{token}"
				attachmentsUrl = "https://api.trello.com/1/cards/#{TEST_CARD_ID}/attachments?fields=name,url&key=#{key}&token=#{token}"
				(console.log { cardUrl }, 'bingo')
				(console.log { attachmentsUrl }, 'bingo')
				request {url: cardUrl, method: 'GET'}, (@err, @cardRes, @cardBody) =>
					if @err? then return
					request {url: attachmentsUrl, method: 'GET'}, (@err, @attsRes, @attsBody) =>
						done()

			it 'Should return card details', (done) ->
				if @err? then console.log { err: err }

				(expect @err).to.not.defined
				(expect @cardRes.statusCode).to.equal 200
				(expect @attsRes.statusCode).to.equal 200
				filename = (sanitize (JSON.parse @cardBody).name)
				content = (JSON.parse @cardBody).desc
				# (console.log body: @cardBody, 'bingo')
				# (console.log body: @attsBody, 'bingo')
				# (console.log { filename }, 'bingo')
				# (console.log { content }, 'bingo')
				console.log { filename }, 'create directory'
				mkdirp "./#{filename}", (err) =>
					if err? then (console.log { err }, 'create directory'); done err
					console.log { filename }, 'converting'
					(markdownpdf().from.string content)
					.to "./#{filename}/contents.pdf", (err) =>
						if err? then (console.log { err }, 'convert'); done err
						tasks = (JSON.parse @attsBody).map (att) =>
							(callback) =>
								console.log { name: att.name }, 'downloading'
								attName = att.name
								ext = path.extname(attName)
								if ext? and ext.length > 0 then attName = "file-" + (attName.replace ext, '') + "-#{att.id}" + ext
								writable = fs.createWriteStream "./#{filename}/#{sanitize attName}"
								writable.on 'finish', callback
								(request att.url).pipe writable
						async.series tasks, (err) =>
							if err? then (console.log { err }, 'download')
							done err
