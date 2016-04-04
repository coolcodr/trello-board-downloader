config = (require 'config')
appCfg = (config.get 'app')
download = (require './lib/download')(appCfg.trello)

boardId = "xxxxxxxxxxxxxxxxxxxxxxxx"

download.board { board: { id: boardId, name: "output" } }
.then (data) => console.log 'finish'
.done()
