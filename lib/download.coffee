assert = (require 'assert-plus')
When = (require 'when')
guard = (require 'when/guard')
request = (require 'request')
sanitize = (require "sanitize-filename")
mkdirp = (require 'mkdirp')
path = (require 'path')
markdownpdf = (require 'markdown-pdf')
async = (require 'async')
fs = (require 'fs')
_ = (require 'lodash')

class Download
	constructor: ({ @key, @token }) ->
		assert.string @key, 'key'
		assert.string @token, 'token'

	boards: =>
		When.promise (resolve, reject) =>
			boardsUrl = "https://api.trello.com/1/members/me/boards?fields=name&key=#{@key}&token=#{@token}";
			options =
				url: boardsUrl
				method: 'GET'
			request options, (err, res, body) =>
				if err? then return reject err
				if res.statusCode isnt 200 then return reject new Error "Get boards, statusCode: #{res.statusCode}"
				resolve JSON.parse body

	board: ({ boardId, output }) =>
		assert.string boardId, 'boardId'
		assert.string output, 'output'

		boardName = null
		@getBoardName { boardId }
		.then (res) =>
			boardName = res._value
			@_lists { boardId }
		.then (lists) =>
			funcs = _.flattenDeep(
				lists.map (list) =>
					list.cards.map (card) =>
						=> @_cards { listName: list.name, cardId: card.id })
			console.log 'start get cards'
			When.map funcs, guard(guard.n(3), (f) => f())
		.then (results) =>
			funcs = results.map (r) =>
				=> @_download { output, boardName, listName: r.listName, card: r.card, atts: r.atts }
			console.log 'start download'
			When.map funcs, guard(guard.n(3), (f) => f())

	getBoardName: ({ boardId }) =>
		assert.string boardId, 'boardId'
		When.promise (resolve, reject) =>
			getBoardNameUrl = "https://api.trello.com/1/boards/#{boardId}/name?key=#{@key}&token=#{@token}"
			options =
				url: getBoardNameUrl
				method: 'GET'
			request options, (err, res, body) =>
				if err? then return reject err
				if res.statusCode isnt 200 then return reject new Error "Get board name: #{boardId}, statusCode: #{res.statusCode}"
				resolve JSON.parse body

	_lists: ({ boardId }) =>
		assert.string boardId, 'boardId'

		When.promise (resolve, reject) =>
			listsUrl = "https://api.trello.com/1/boards/#{boardId}/lists?cards=open&card_fields=name&fields=name&key=#{@key}&token=#{@token}"
			# (console.log { listsUrl }, 'get lists')
			options =
				url: listsUrl
				method: 'GET'
			request options, (err, res, body) =>
				if err? then return reject err
				if res.statusCode isnt 200 then return reject new Error "Get lists: #{boardId}, statusCode: #{res.statusCode}"
				resolve JSON.parse body

	_cards: ({ listName, cardId }) =>
		assert.string listName, 'listName'
		assert.string cardId, 'cardId'

		When.promise (resolve, reject) =>
			cardUrl = "https://api.trello.com/1/cards/#{cardId}?fields=name,desc&key=#{@key}&token=#{@token}"
			(console.log { cardUrl }, 'get card')
			request {url: cardUrl, method: 'GET'}, (err, cardRes, cardBody) =>
				if err? then return reject err
				if cardRes.statusCode isnt 200 then return reject new Error "Get card: #{cardId}, statusCode: #{cardRes.statusCode}"
				card = (JSON.parse cardBody)
				attachmentsUrl = "https://api.trello.com/1/cards/#{cardId}/attachments?fields=name,url&key=#{@key}&token=#{@token}"
				# (console.log { attachmentsUrl }, 'get attachments')
				request {url: attachmentsUrl, method: 'GET'}, (err, attsRes, attsBody) =>
					if err? then return reject err
					if attsRes.statusCode isnt 200 then return reject new Error "Get attachments: #{cardId}, statusCode: #{attsRes.statusCode}"
					atts = (JSON.parse attsBody)
					resolve { listName, card, atts }

	_download: ({ output, boardName, listName, card, atts }) =>
		assert.string output, 'output'
		assert.string listName, 'listName'
		assert.string boardName, 'boardName'
		assert.object card, 'card'
		assert.arrayOfObject atts, 'atts'

		When.promise (resolve, reject) =>
			directory = "#{output}/#{sanitize boardName}/#{(sanitize listName)}/#{(sanitize card.name)}"
			cardPdf = "#{directory}/card.pdf"
			mkdirp directory, (err) =>
				if err? then return reject err
				async.parallel {
					makePdf: (callback) =>
						console.log { name: card.name }, 'converting'
						content = ("# #{card.name}\n" + card.desc)
						(markdownpdf().from.string content)
						.to cardPdf, (err) => callback err, output
					download: (callback) =>
						tasks = atts.map (att) =>
							(done) =>
								console.log { name: att.name }, 'downloading'
								attName = att.name
								ext = (path.extname attName)
								if ext? and ext.length > 0 then attName = "file-" + (attName.replace ext, '') + "-#{att.id}" + ext
								attachmentPath = "#{directory}/#{(sanitize attName)}"
								writable = fs.createWriteStream attachmentPath
								writable.on 'finish', -> done null, { attachmentPath }
								(request att.url).pipe writable
						if tasks.length > 0
							async.series tasks, callback
						else
							callback()
				}, (err, results) =>
					if err? then return reject err
					resolve results

module.exports = (params) => new Download params
