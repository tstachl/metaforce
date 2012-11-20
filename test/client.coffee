should = require 'should'
fs     = require 'fs'
path   = require 'path'
Client = require '../lib/client'
Zip    = require 'node-zip'

username = process.env.USERNAME or ''
password = process.env.PASSWORD or ''

describe 'Client', ->
  client = new Client()
  describe 'Constructor', ->
    it 'should use default values if none given', ->
      constr = new Client()
      constr.apiVersion.should.equal 26.0
      constr.username.should.equal ''
      constr.password.should.equal ''
      constr.endpoint.should.equal 'https://login.salesforce.com/services/Soap/u/26.0'
      constr.sid.should.equal ''
      constr.userId.should.equal ''
      constr.overrideSessionCheck.should.equal no
    
    it 'should use settings from options when given', ->
        constr = new Client
          apiVersion: 24.0
          username: 'thomas@stachl.me'
          password: 'something'
          endpoint: 'test.salesforce.com'
          sid: 'somelongsidstring'
          userId: 'someuserid'
          overrideSessionCheck: yes
        
        constr.apiVersion.should.equal 24.0
        constr.username.should.equal 'thomas@stachl.me'
        constr.password.should.equal 'something'
        constr.endpoint.should.equal 'https://test.salesforce.com/services/Soap/u/26.0'
        constr.sid.should.equal 'somelongsidstring'
        constr.userId.should.equal 'someuserid'
        constr.overrideSessionCheck.should.equal yes
  
  describe 'login', ->
    it 'should not work with invalid credentials', (done) ->
      client.login username: 'somewrong@username.com', password: 'nothing', (err, response, request) ->
        (->
          throw err if err
        ).should.throwError()
        done()
        
    it 'should work valid credentials and setup the session id, user id and endpoints', (done) ->
      client.login username: username, password: password, (err, response, request) ->
        throw err if err
        client.endpoint.should.equal response.result.serverUrl
        client.sid.should.equal response.result.sessionId
        client.userId.should.equal response.result.userId
        done()
    
    it 'should login with the session id defined and fetch user information', (done) ->
      clientb = new Client sid: client.sid, endpoint: client.endpoint
      clientb.getUserInfo (err, response, request) ->
        throw err if err
        response.result.userName.should.equal 'thomas@stachl.me'
        done()

  describe 'query', ->
    it 'should return a query result', (done) ->
      client.query queryString: 'Select Id From Account', (err, response, request) ->
        should.exist response.result.records
        done()
  
  describe 'compileApex', ->
    it 'should compile a valid apex class', (done) ->
      fs.readFile path.resolve("#{__dirname}/data/ValidCompileTest.cls"), 'utf8', (err, data) ->
        throw err if err
        client.compileApex type: 'ApexClass', scripts: data, (err, response, request) ->
          throw err if err
          for result in response.result
            result.success.should.be.true
          done()

    it 'should not compile an invalid apex class', (done) ->
      fs.readFile path.resolve("#{__dirname}/data/InvalidCompileTest.cls"), 'utf8', (err, data) ->
        throw err if err
        client.compileApex type: 'ApexClass', scripts: data, (err, response, request) ->
          throw err if err
          for result in response.result
            result.success.should.not.be.true
          done()
                
    it 'should compile a valid apex trigger', (done) ->
      fs.readFile path.resolve("#{__dirname}/data/ValidCompileTrigger.cls"), 'utf8', (err, data) ->
        throw err if err
        client.compileApex type: 'ApexTrigger', scripts: data, (err, response, request) ->
          throw err if err
          for result in response.result
            result.success.should.be.true
          done()

    it 'should not compile an invalid apex trigger', (done) ->
      fs.readFile path.resolve("#{__dirname}/data/InvalidCompileTrigger.cls"), 'utf8', (err, data) ->
        throw err if err
        client.compileApex type: 'ApexTrigger', scripts: data, (err, response, request) ->
          throw err if err
          for result in response.result
            result.success.should.not.be.true
          done()

  describe 'executeApex', ->
    it 'should return successful', (done) ->
      client.executeApex apexcode: 'System.debug(\'Test\');', (err, response, request) ->
        throw err if err
        response.result.success.should.be.true
        done()
    
    it 'should return unsuccessful', (done) ->
      client.executeApex apexcode: 'System.debug(\'Test\')', (err, response, request) ->
        throw err if err
        response.result.success.should.not.be.true
        done()
    
    it 'should return a DebuggingInfo header', (done) ->
      args = 
        apexcode: 'System.debug(\'Test\');'
        debugLevel: 'Detail'
        categories: [
          { category: 'All', level: 'Finest' }
        ]
      
      client.executeApex args, (err, response, request, header) ->
        throw err if err
        response.result.success.should.be.true
        header.DebuggingInfo.should.exist
        header.DebuggingInfo.debugLog.should.include('Execute Anonymous')
        done()
      
  describe 'runTests', ->
    it 'should run all tests if specified', (done) ->
      client.runTests allTests: yes, (err, response, request) ->
        throw err if err
        response.result.numTestsRun.should.exist
        done()
  
  describe 'retrieve', ->
    it 'should return an id for the package we want to retrieve', (done) ->
      client.retrieve unpackaged: types: [{ members: '*', name: 'ApexPage' }], (err, response, request) ->
        throw err if err
        response.result.id.should.be.ok
        done()
    
    it 'should keep on checking the status and return the zip file once done', (done) ->
      client.retrieve wait: yes, unpackaged: types: [{ members: '*', name: 'ApexPage' }], (err, response, request) ->
        throw err if err
        response.result.zipFile.should.be.ok
        done()
    
  describe 'deploy', ->
    it 'should try to deploy a zip package and return an id', (done) ->
      zip = new Zip()
      zip.folder path.resolve "#{__dirname}/data/deploy_create_src"
      
      args =
        zipFile: zip.generate()
        deployOptions:
          checkOnly: yes
      
      client.deploy args, (err, response, request) ->
        throw err if err
        response.result.id.should.be.ok
        done()
    
    it 'should keep on checking the status and return the result once done', (done) ->
      zip = new Zip()
      zip.folder path.resolve "#{__dirname}/data/deploy_create_src"
      
      args =
        wait: yes
        zipFile: zip.generate()
        deployOptions:
          checkOnly: yes
      
      client.deploy args, (err, response, request) ->
        throw err if err
        response.result.success.should.be.true
        done()
    
    it 'should delete Start_Here on a destructive change call', (done) ->
      zip = new Zip()
      zip.folder path.resolve "#{__dirname}/data/deploy_delete_src"
      
      args =
        wait: yes
        zipFile: zip.generate()
        deployOptions:
          checkOnly: yes

      client.deploy args, (err, response, request) ->
        throw err if err
        response.result.success.should.be.true
        done()
      
  describe 'describe', ->
    it 'should describe the organization', (done) ->
      client.describe (err, response, request) ->
        throw err if err
        response.result.metadataObjects.should.be.an.instanceOf Array
        response.result.organizationNamespace.should.exist
        done()
  
  describe 'list', ->
    it 'should list the property information about metadata components', (done) ->
      client.list queries: type: 'ApexClass', (err, response, request) ->
        throw err if err
        response.result.should.be.an.instanceOf Array
        done()