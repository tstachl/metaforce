# **Client** is the API client for the Force.com Metadata, Partner and
# Apex API. It doesn't do anything else but interact with the api based
# on options you pass to the specific method. At the moment it only
# contains methods needed for the Force.com CLI and the Force.com Cloud9
# extension.

## Dependencies ##

# Soap contributes a Node Soap Client to talk to the API
soap    = require 'soap'
# We need path to resolve the path to the WSDL files
path    = require 'path'

## The Client Class ##
module.exports = class Client
  #### Constructor ####
  # The Constructor just sets a few basic variables, all of those are
  # optional.
  #
  #     @param {object} opts
  #       {
  #         apiVersion: 26.0,
  #         username: '',
  #         password: '',
  #         endpoint: 'login.salesforce.com',
  #         sid: '',
  #         userId: '',
  #         overrideSessionCheck: false
  #       }
  #     @return {Client} this
  #     @api public
  constructor: (opts = {}) ->
    @apiVersion           = opts.apiVersion or 26.0
    @username             = opts.username or ''
    @password             = opts.password or ''
    @endpoint             = opts.endpoint or 'login.salesforce.com'
    
    unless ~@endpoint.indexOf 'https'
      @endpoint = "https://#{@endpoint}"
    unless ~@endpoint.indexOf '/services'
      @endpoint += '/services/Soap/u/26.0'
    
    @sid                  = opts.sid or ''
    @userId               = opts.userId or ''
    @overrideSessionCheck = opts.overrideSessionCheck or no
  
  ### Partner API calls ###
  #### login() ####
  # If not already logged in this should be the first call it'll setup default
  # params like user id and the metadata server url.
  #
  #     @param {object} opts
  #       {
  #         username: '',
  #         password: '',
  #         endpoint: ''
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  login: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    return @fromSession callback unless @sid is ''
    
    opts.username = opts.username or @username
    opts.password = opts.password or @password
    
    @endpoint = opts.endpoint or @endpoint
    delete opts.endpoint
    
    @client 'partner', (err, client) =>
      @performCall client, 'login', opts, (err, response, lastRequest) =>
        return callback err if err
        
        @_sessionResponse = response
        if response.result?
          @sid = response.result.sessionId or ''
          @userId = response.result.userId or ''
          @endpoint = response.result.serverUrl
          client.setEndpoint @endpoint
        
        callback err, response, lastRequest
    return
      
  #### getUserInfo() ####
  # Returns a hash of information on the user that's currently logged in.
  #
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  getUserInfo: (callback) ->
    @client 'partner', (err, client) =>
      @performCall client, 'getUserInfo', null, callback
    return
  
  #### query() ####
  # Allows you to run a SOQL query against the current organizations database.
  #
  #     @param {object} opst
  #       {
  #         queryString: ''
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  query: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    @client 'partner', (err, client) =>
      @performCall client, 'query', opts, callback
    return
  
  ### Apex API calls ###
  #### compileApex() ####
  # Compile Apex tries to compile the apex code of a class or a trigger
  # it'll return a Compile[Class|Trigger]Result. To get further information 
  # on the response check out the [Salesforce documentation](http://www.salesforce.com/us/developer/docs/apexcode/Content/sforce_api_calls_compileandtest_result.htm)
  #
  #     @param {object} opts
  #       {
  #         type: 'ApexTrigger|ApexClass',
  #         scripts: ''
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  compileApex: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    
    type = if opts.type == 'ApexTrigger' then 'compileTriggers' else 'compileClasses'
    delete opts.type
    opts.scripts = opts.scripts or ''
    
    @client 'apex', (err, client) =>
      @performCall client, type, opts, callback
    return

  #### executeApex() ####
  # This method executes apex code anonymously on the platform and returns
  # the debug log to a certain extend. You can influence the categories
  # and the debug level with values found here in the [documentation](http://www.salesforce.com/us/developer/docs/apexcode/Content/sforce_api_header_debuggingheader.htm)
  #
  #     @param {object} opts
  #       {
  #         apexcode: '',
  #         categories: [
  #           { category: 'Apex_code', level: 'Debug' }
  #         ],
  #         debugLevel: 'Debugonly'
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  executeApex: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    [opts, debug] = @prepareDebugHeader opts
    
    opts.apexcode = opts.apexcode or ''
    
    @client 'apex', (err, client) =>
      @performCall client, 'executeAnonymous', opts, callback, debug
    return
  
  #### runTests() ####
  # If you tell this method the tests you want to be run it'll run them and
  # return a detailed result with debug log. To influence the debugging
  # you can set sepecific settings found here in the [documentation](http://www.salesforce.com/us/developer/docs/apexcode/Content/sforce_api_header_debuggingheader.htm)
  #
  #     @param {object} opts
  #       {
  #         allTests: true|false,
  #         classes: [
  #           ''
  #         ],
  #         namespace: ''
  #         categories: [
  #           { category: 'Apex_code', level: 'Debug' }
  #         ],
  #         debugLevel: 'Debugonly'
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  runTests: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    [opts, debug] = @prepareDebugHeader opts
    
    opts.namespace = opts.namespace or '' # @orgNamespace() or ''
    
    @client 'apex', (err, client) =>
      @performCall client, 'runTests', request: opts, callback, debug
    return
    
  ### MetaData API calls ###
  #### retrieve() ####
  # Retrieve will start a zip process on the server for the required
  # metadata. The response contains an Id which is used to check the
  # status of the packaging process and to download the zip file once
  # packaged. Specifics on the response can be found here in the
  # [documentation](http://www.salesforce.com/us/developer/docs/api_meta/Content/meta_asyncresult.htm)
  #
  #     @param {object} opts
  #       {
  #         apiVersion: 26.0
  #         packageNames: [
  #           ''
  #         ],
  #         singlePackage: true|false,
  #         specificFiles: [
  #           ''
  #         ],
  #         unpackaged: {
  #           apiAccessLevel: 'Unrestricted|Restricted',
  #           description: '',
  #           fullName: '',
  #           namespacePrefix: '',
  #           objectPermissions: [{
  #             allowCreate: true|false,
  #             allowDelete: true|false,
  #             allowEdit: true|false,
  #             allowRead: true|false,
  #             modifyAllRecords: true|false,
  #             object: '',
  #             viewAllRecords: true|false,
  #           }],
  #           setupWeblink: '',
  #           types: [
  #             { members: '', name: '' }
  #           ],
  #           version: ''
  #         }
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  retrieve: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    
    if opts.wait
      delete opts.wait
      callback = @createCheckStatus callback, 'checkRetrieveStatus'
    
    @client 'metadata', (err, client) =>
      @performCall client, 'retrieve', retrieveRequest: opts, callback
    return
  
  #### checkRetrieveStatus() ####
  # Checks the status of declarative metadata call retrieve() and returns the zip
  # contents.
  #
  #     @param {object} opts
  #       {
  #         id: ''
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  checkRetrieveStatus: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    @client 'metadata', (err, client) =>
      @performCall client, 'checkRetrieveStatus', opts, callback
    return
  
  #### deploy() ####
  # This method takes a zip file (base64 encoded) and sends it to the
  # server, based on the contents of the zip file it'll perform a 
  # create, update or delete.
  #
  #     @param {object} opts
  #       {
  #         zipFile: '',
  #         deployOptions: {
  #           allowMissingFiles: true|false,
  #           autoUpdatePackage: true|false,
  #           checkOnly: true|false,
  #           ignoreWarnings: true|false,
  #           performRetrieve: true|false,
  #           purgeOnDelete: true|false,
  #           rollbackOnError: true|false,
  #           runAllTests: true|false,
  #           runTests: [
  #             ''
  #           ],
  #           singlePackage: true|false
  #         }
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  deploy: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    
    if opts.wait
      delete opts.wait
      callback = @createCheckStatus callback, 'checkDeployStatus'
    
    @client 'metadata', (err, client) =>
      @performCall client, 'deploy', opts, callback
    return
  
  
  #### checkDeployStatus() ####
  # Checks the status of declarative metadata call deploy().
  #
  #     @param {object} opts
  #       {
  #         id: ''
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  checkDeployStatus: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    @client 'metadata', (err, client) =>
      @performCall client, 'checkDeployStatus', opts, callback
    return
  
  #### describe() ####
  # This call retrieves metadata which describes the organization.
  # 
  #     @param {object} opts
  #       {
  #         apiVersion: 26.0
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  describe: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    opts.apiVersion = opts.apiVersion or @apiVersion
    @client 'metadata', (err, client) =>
      @performCall client, 'describeMetadata', opts, callback
    return

  #### list() ####
  # Retrieve property information about the metadata components in the
  # organization.
  # 
  #     @param {object} opts
  #       {
  #         queries: [{
  #           folder: ''
  #           type: ''
  #         }],
  #         asOfVersion: 26.0
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  list: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    opts.asOfVersion = parseFloat(opts.asOfVersion or @apiVersion).toFixed(1)
    @client 'metadata', (err, client) =>
      @performCall client, 'listMetadata', opts, callback
    return
  
  ### Public Helper Methods ###
  #### checkStatus ####
  # Checks the status of asynchronous metadata calls create(), update(), delete() or
  # the declarative metadata calls deploy() or retrieve().
  #
  #     @params {object} opts
  #       {
  #         ids: [
  #           ''
  #         ]
  #       }
  #     @param {function} callback(err, response, request)
  #     @return void
  #     @api public
  checkStatus: (opts, callback) ->
    [opts, callback] = @cleanOptions opts, callback
    @client 'metadata', (err, client) =>
      @performCall client, 'checkStatus', opts, callback
    return
  
  ### Private Helper Methods ###
  #### createCheckStatus() ####
  # Creates a check loop function used in retrieve() and deploy() if you set
  # the option wait to true.
  #
  #     @param {function} callback
  #     @param {string} checkMethodName
  #     @return {function}
  #     @api private
  createCheckStatus: (callback, checkMethodName) ->
    return checkStatus = (err, response, request) =>
      return callback err if err
      response.result = response.result[0] if Array.isArray response.result
            
      if response.result.done
        return @[checkMethodName] id: response.result.id, callback
    
      process.nextTick =>
        @checkStatus ids: [response.result.id], checkStatus
  
  #### fromSession() ####
  # This helper method get's called if you try to call a method having the client
  # setup only with the session id and the endpoint. It'll use the current session
  # and try to get additional user information. As an indicator we use the users
  # id, if set it'll assume the session is alive otherwise it'll try and fetch it.
  #
  #     @param {soap.Client} client
  #     @param {string} method
  #     @param {object} opts
  #     @param {callback} callback(err, response, lastRequest)
  #     @param {object|boolean} debugHeader
  #     @return void
  #     @api private
  fromSession: (callback) ->
    if @endpoint and @sid and @userId and @_sessionResponse
      callback null, @_sessionResponse
    else
      @client 'partner', (err, client) =>
        client.soapHeaders = []
        client.addSoapHeader @getSoapHeader(), null, 'tns'
        client.getUserInfo (err, response) =>
          return callback err if err
          @userId = response.result.userId
          callback err, @_sessionResponse = response
  
  #### performCall() ####
  # This method performs the actual call to the API. Afterwards it'll call the
  # callback function with the response.
  #
  #     @param {soap.Client} client
  #     @param {string} method
  #     @param {object} opts
  #     @param {callback} callback(err, response, lastRequest)
  #     @param {object|boolean} debugHeader
  #     @return void
  #     @api private
  performCall: (client, method, opts, callback, debugHeader = false) ->
    if not @userId and @endpoint and @sid
      return @fromSession (err, response) =>
        return callback err if err
        @performCall client, method, opts, callback, debugHeader
    
    client.soapHeaders = []
    client.addSoapHeader @getSoapHeader(), null, 'tns' if @sid
    client.addSoapHeader debugHeader, null, 'tns' if debugHeader
    client[method] opts, (err, response, body) =>
      unless err 
        header = client.wsdl.xmlToObject(body).Header
      callback err, response, client.lastRequest, header or {}
    return
  
  #### getSoapHeader() ####
  # Returns the Session Header
  #
  # @return {object} SessionHeader
  # @api private
  getSoapHeader: ->
    SessionHeader: sessionId: @sid
  
  #### prepareDebugHeader() ####
  # Returns the Debug Header object
  #
  #     @param {object} opts
  #     @return {object} DebugHeader
  #     @api private
  prepareDebugHeader: (opts) ->
    debug = 
      DebuggingHeader:
        debugLevel: opts.debugLevel or 'Debugonly'
        categories: opts.categories or [{ category: 'Apex_code', level: 'Debug' }]
    delete opts.categories
    delete opts.debugLevel
    [opts, debug]
  
  #### cleanOptions() ####
  # Returns an array with cleaned arguments this allows you to call a method
  # without having to set options.
  #
  #     @param {object} opts
  #     @param {function} callback
  #     @return {array} [opts, callback]
  #     @api private
  cleanOptions: (opts, callback) ->
    if typeof opts == 'function'
      callback = opts
      opts = {}
    [opts, callback]
  
  #### client() ####
  # Function to create a SOAP client for the defined wsdl.
  #
  #     @param {string} type
  #     @param {function} callback
  #     @return {soap.Client}
  #     @api private
  client: (type, callback) ->
    return callback null, @["_#{type}Client"] if @["_#{type}Client"]
    
    wsdl = path.resolve(__dirname, "../wsdl/#{@apiVersion.toFixed(1)}/#{type}.xml")
    
    switch type
      when 'metadata' then repl = '/m/'
      when 'apex' then repl = '/s/'
      else repl = '/u/'
    
    soap.createClient wsdl, (err, client) =>
      client.setEndpoint @endpoint.replace /\/u\//, repl
      @["_#{type}Client"] = client
      callback err, client