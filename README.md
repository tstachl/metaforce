_metaforce_ is a small Salesforce API client that makes working with the Salesforce Metadata, Partner and Apex API as easy as possible. 

## Installation
_metaforce_ is currently in an alpha state and therefore not on npmjs.org but we'll be getting there hopefully soon. For now you can install the package by defining the git url in your `package.json`:

    ...
    "dependencies": {
      "metaforce": "git://github.com/tstachl/metaforce.git#master",
      ...
    },
    ...

## Dependencies
The package depends on the [node-soap project](https://github.com/milewise/node-soap) lead by [@milewise](https://github.com/milewise).

  * [node-soap](https://github.com/tstachl/node-soap)
  * [coffee-script](http://coffeescript.org)

## The Client
*Client* is the API client for the Force.com Metadata, Partner and Apex API. It doesn't do anything else but interact with the api based on options you pass to the specific method. At the moment it only contains methods needed for the [Force.com CLI](https://github.com/tstachl/force) and the [Force.com Cloud9 Extension](https://github.com/tstachl/cloud9-forcecom-ext), but hopefully it'll soon be a full representation of the API and include a few methods to verify the options you use for the methods.

### Public Methods
Before you can start sending off api calls you have two ways of constructing the client:

    // both sid and endpoint are required to work from a session
    var clientFromSession = new Client({
      sid: 'MySessionId',
      endpoint: 'https://na7-api.salesforce.com/services/Soap/u/26.0'
    });
    
    // if you have a username and a password
    var client = new Client();

#### Partner API calls
##### login()
If not already logged in this should be the first call it'll setup default params like user id and the metadata server url.

    client.login({
      username: 'my@username.com',
      password: 'mypassword',
      endpoint: 'login.salesforce.com' // or test.salesforce.com
    }, function(err, response, request) {
      // this call defines the following variables:
      client.endpoint
      client.sid
      client.userId
    });

##### getUserInfo()
Returns a hash of information on the user that's currently logged in.

    client.getUserInfo(function(err, response, request) {
      var userInfo = response.result;
    });

##### query()
Allows you to run a SOQL query against the current organizations database.

    client.query({
      queryString: 'Select Id From Account'
    }, function(err, response, request) {
      var queryResult = response.result;
    });

#### Apex API calls
##### compileApex()
Compile Apex tries to compile the apex code of a class or a trigger it'll return a Compile[Class|Trigger]Result. To get further information on the response check out the [Salesforce documentation](http://www.salesforce.com/us/developer/docs/apexcode/Content/sforce_api_calls_compileandtest_result.htm)

    client.compileApex({
      type: 'ApexClass', // or ApexTrigger
      scripts: 'public class ...'
    }, function(err, response, request) {
      var compileResult = response.result;
    });

##### executeApex()
This method executes apex code anonymously on the platform and returns the debug log to a certain extend. You can influence the categories and the debug level with values found here in the [documentation](http://www.salesforce.com/us/developer/docs/apexcode/Content/sforce_api_header_debuggingheader.htm)

    client.executeApex({
      apexcode: 'System.debug(\'Test\');',
      categories: [
        { category: 'Apex_code', level: 'Debug' }
      ],
      debugLevel: 'Debugonly'
    }, function(err, response, request, header) {
      var executeResult = response.result;
      var debuggingInfo = header.DebuggingInfo;
    });

##### runTests()
If you tell this method the tests you want to be run it'll run them and return a detailed result with debug log. To influence the debugging you can set sepecific settings found here in the [documentation](http://www.salesforce.com/us/developer/docs/apexcode/Content/sforce_api_header_debuggingheader.htm)

    client.runTests({
      allTests: true,
      categories: [
        { category: 'Apex_code', level: 'Debug' }
      ],
      debugLevel: 'Debugonly'
    }, function(err, response, request, header) {
      var testResult = response.result;
      var debuggingInfo = header.DebuggingInfo;
    });

#### Metadata API calls
##### retrieve()
Retrieve will start a zip process on the server for the required metadata. The response contains an Id which is used to check the status of the packaging process and to download the zip file once packaged. Specifics on the response can be found here in the [documentation](http://www.salesforce.com/us/developer/docs/api_meta/Content/meta_asyncresult.htm)

    client.retrieve({
      unpackaged: {
        types: [{ 
          members: '*', 
          name: 'ApexPage'
        }]
      }
    }, function(err, response, request) {
      var retrieveId = response.result.id;
    });

##### checkRetrieveStatus()
Checks the status of declarative metadata call retrieve() and returns the zip contents.

    client.checkRetrieveStatus({
      id: 'IdFromRetrieve'
    }, function(err, response, request) {
      var zipFile = response.result.zipFile;
    });

##### deploy()
This method takes a zip file (base64 encoded) and sends it to the server, based on the contents of the zip file it'll perform a create, update or delete.

    client.deploy({
      zipFile: 'Base64 encoded zip file',
      deployOptions: {
        checkOnly: true
      }
    }, function(err, response, request) {
      var deployId = response.result.id;
    });

##### checkDeployStatus()
Checks the status of declarative metadata call deploy().

    client.checkDeployStatus({
      id: 'IdFromDeploy'
    }, function(err, response, request) {
      var success = response.result.success;
    });

##### describe()
This call retrieves metadata which describes the organization.

    client.describe({
      apiVersion: '26.0'
    }, function(err, response, request) {
      var describeResult = response.result;
    });

##### list()
Retrieve property information about the metadata components in the organization.

    client.list({
      queries: [{
        type: 'ApexClass'
      }],
      asOfVersion: '26.0'
    }, function(err, response, request) {
      var listResult = response.result;
    });

#### Public Helper Methods
##### checkStatus()
Checks the status of asynchronous metadata calls create(), update(), delete() or the declarative metadata calls deploy() or retrieve().

    client.checkStatus({
      ids: ['RetrieveOrDeployId']
    }, function(err, response, request) {
      var isDone = response.result[0].done;
    });

### Contributions
We'd love to see some pull requests. Please make sure you add tests to your contributions and make sure it doesn't break any of the existing code.

#### Requirements
  * A clean Developer Org to run the tests [get one here](http://www.developerforce.com/events/regular/registration.php)
  * Understanding of [CoffeeScript](http://coffeescript.org)

#### Dependencies
  * [Mocha](https://github.com/visionmedia/mocha)
  * [Should.js](https://github.com/visionmedia/should.js)
  * [node-zip](https://github.com/daraosn/node-zip)
  * [Commander.js](https://github.com/visionmedia/commander.js)

#### Running test
We created a little wrapper around the test because most test cases need a valid login to your developer org.

    $ npm test
    
    > metaforce@0.0.1 test /Users/tstachl/Workspaces/Github/metaforce
    > test/runner
    
    Username: your@developeredition.com
    Password: ******************
    
    ...  Mocha Test Output ...

You can also start the test runner by typing:

    $ test/runner

Here is a little usage information:

    $ test/runner --help
    
    Usage: runner [options]

    Options:

      -h, --help                 output usage information
      -u, --username [username]  The username for the developer org.
      -p, --passwd [password]    The password for the developer org.
      -f, --file [file]          The file you want to test.
