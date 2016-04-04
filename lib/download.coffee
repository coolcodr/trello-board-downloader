assert = (require 'assert-plus')
When = (require 'when')
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

	board: ({ board }) =>
		assert.object board, 'board'
		assert.string board.name, 'board.name'
		assert.string board.id, 'board.id'

		@_lists { boardId: board.id }
		.then (lists) =>
			promises = _.flattenDeep(
				lists.map (list) =>
					list.cards.map (card) =>
						@_cards { listName: list.name, cardId: card.id })
			When.all promises
		.then (results) =>
			promises = results.map (r) =>
				@_download { boardName: board.name, listName: r.listName, card: r.card, atts: r.atts }
			When.all promises

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
			# (console.log { cardUrl }, 'get card')
			request {url: cardUrl, method: 'GET'}, (err, cardRes, cardBody) =>
				if err? then return reject err
				if cardRes.statusCode isnt 200 then return reject new Error "Get card: #{cardId}, statusCode: #{cardRes.statusCode}"
				card = (JSON.parse cardBody)
				cardName = card.name
				attachmentsUrl = "https://api.trello.com/1/cards/#{cardId}/attachments?fields=name,url&key=#{@key}&token=#{@token}"
				# (console.log { attachmentsUrl }, 'get attachments')
				request {url: attachmentsUrl, method: 'GET'}, (err, attsRes, attsBody) =>
					if err? then return reject err
					if attsRes.statusCode isnt 200 then return reject new Error "Get attachments: #{cardId}, statusCode: #{attsRes.statusCode}"
					atts = (JSON.parse attsBody)
					resolve { listName, card, atts }

	_download: ({ boardName, listName, card, atts }) =>
		assert.string boardName, 'boardName'
		assert.string listName, 'listName'
		assert.object card, 'card'
		assert.arrayOfObject atts, 'atts'

		When.promise (resolve, reject) =>
			directory = "#{boardName}/#{(sanitize listName)}/#{(sanitize card.name)}"
			mkdirp directory, (err) =>
				if err? then return reject err
				console.log { name: card.name }, 'converting'
				output = "#{directory}/contents.pdf"
				markdownpdf().from.string ("# #{card.name}\n" + card.desc)
				.to output, (err) =>
					if err? then return reject err
					tasks = atts.map (att) =>
						(callback) =>
							console.log { name: att.name }, 'downloading'
							attName = att.name
							ext = path.extname(attName)
							if ext? and ext.length > 0 then attName = "file-" + (attName.replace ext, '') + "-#{att.id}" + ext
							attachmentPath = "#{directory}/#{(sanitize attName)}"
							writable = fs.createWriteStream attachmentPath
							writable.on 'finish', -> callback null, { attachmentPath }
							(request att.url).pipe writable
					if tasks.length > 0
						async.series tasks, (err, attachments) =>
							if err? then return reject err
							resolve { contents: output, attachments }
					else
						resolve { contents: output }

module.exports = (params) => new Download params
