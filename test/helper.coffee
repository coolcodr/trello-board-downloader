sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'

class Helper
	constructor: ->
		chai.use sinonChai
		chai.should()	# activate the should syntax for message expectations

	# test framework components
	sinon: sinon
	match: sinon.match.bind sinon
	stub: sinon.stub.bind sinon
	expect: chai.expect

module.exports = helper = new Helper
