config = (require 'config')
program = (require 'commander')
trelloCfg = (config.get 'trello')

{ key, token } = trelloCfg

program
.version('0.0.1')
.usage('[options] <board-id>')
.option('-k, --key [key]', 'Trello app key', key)
.option('-t, --token [token]', 'Trello app token', token)
.option('-o, --output [output path]', 'Output path', 'output')
.parse(process.argv);

{ key, token, output, args } = program

if not key?
	urlGetKey = "https://trello.com/app-key"
	return console.log "Please visit the url to get the app key: #{urlGetKey}"

if not token?
	urlGetToken = "https://trello.com/1/authorize?key=#{key}&name=TrelloBoardDownloader&expiration=never&response_type=token";
	return console.log "Please visit the url to get the app token: #{urlGetToken}"

argv = { key, token, output, args }
(console.info argv, 'arguments')

download = ((require './lib/download') { key, token })

if args.length == 0
	download.boards()
	.then (boards) => console.log { boards }
	.done()
else
	boardId = args[0]
	download.board { boardId, output: output }
	.then (data) => console.log 'finish'
	.done()
