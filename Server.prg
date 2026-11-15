*------------------------------------------------------------------------
*  Function: Start the FoxDev Studio HTTP server and register the routes
*    Params: tnPort - Port to listen on, 3000 when empty
*   Returns: None
*      Note: FoxDev Studio always binds 127.0.0.1. Listen() does not wait:
*            the routes answer until the program is cancelled in the studio.
*            Request  : req.Method, req.Path, req.Body,
*                       req.Query("name"), req.Params("name"), req.Header("name")
*            Response : res.Status(n), res.Header("name", "value"),
*                       res.Send(text) = text/plain, res.Json(text) = application/json
*            Route    : "/user/:id" = one segment, "/*path" = rest of the path
*------------------------------------------------------------------------
LPARAMETERS tnPort
LOCAL loServer, lnPort, lnBound, loException

* The lambdas run after this program has ended: keep the helpers and the Process class loaded
SET PROCEDURE TO Server ADDITIVE
SET PROCEDURE TO Process ADDITIVE

DO CASE
	CASE VARTYPE(tnPort) == "N" AND tnPort > 0
		lnPort = INT(tnPort)
	CASE VARTYPE(tnPort) == "C" AND VAL(tnPort) > 0
		lnPort = INT(VAL(tnPort))
	OTHERWISE
		lnPort = 3000
ENDCASE

ACTIVATE SCREEN
CLEAR
? "Starting FoxDev Studio HTTP Server on 127.0.0.1:" + TRANSFORM(lnPort) + "..."

loServer = FoxScript.Http.CreateServer()

* 1. Root status check
loServer.Get("/", LAMBDA(req, res)
	res.Json('{"app": "FoxDev Studio Web Server", "version": "0.1.0", "status": "online", ' + ;
		'"serverTime": "' + TTOC(DATETIME()) + '"}')
ENDLAMBDA)

* 2. Simple text response
loServer.Get("/api/welcome", LAMBDA(req, res)
	res.Send("Welcome to the modern Visual FoxPro backend runtime via FoxDev Studio!")
ENDLAMBDA)

* 3. Query parameters ( /api/search?q=foxpro&limit=10 )
loServer.Get("/api/search", LAMBDA(req, res)
	LOCAL lcQuery, lnLimit
	lcQuery = req.Query("q")
	lnLimit = INT(VAL(EVL(req.Query("limit"), "5")))

	IF EMPTY(lcQuery)
		res.Status(400)
		res.Json([{"error": "Missing required query parameter 'q'."}])
	ELSE
		res.Json('{' + ;
			'"searchQuery": "' + JsonEscape(lcQuery) + '", ' + ;
			'"maxResults": ' + TRANSFORM(lnLimit) + ', ' + ;
			'"results": [' + ;
				'{"id": 1, "title": "FoxPro Enterprise Architecture", "score": 0.98}, ' + ;
				'{"id": 2, "title": "Migrating VFP to FoxDev Studio", "score": 0.92}' + ;
			']}')
	ENDIF
ENDLAMBDA)

* 4. POST with a JSON body ( {"username": "admin", "password": "secret"} )
loServer.Post("/api/session/login", LAMBDA(req, res)
	LOCAL lcUser, lcPass, loBody, loException
	lcUser = ""
	lcPass = ""

	* req.Body is plain text: an invalid body or a missing field leaves the values empty
	TRY
		loBody = FoxScript.Json.Parse(req.Body)
		lcUser = loBody.username
		lcPass = loBody.password
	CATCH TO loException
		lcUser = ""
		lcPass = ""
	ENDTRY

	DO CASE
		CASE EMPTY(lcUser) OR EMPTY(lcPass)
			res.Status(400)
			res.Json([{"error": "Both username and password are required fields."}])

		CASE lcUser == "admin" AND lcPass == "secret"
			res.Header("X-Session-Authenticated", "true")
			res.Json('{' + ;
				'"success": true, ' + ;
				'"username": "' + JsonEscape(lcUser) + '", ' + ;
				'"sessionId": "' + SYS(2015) + SYS(2015) + '", ' + ;
				'"expiresIn": 3600, ' + ;
				'"message": "Session successfully established."' + ;
				'}')

		OTHERWISE
			res.Status(401)
			res.Json([{"success": false, "error": "Invalid credentials provided."}])
	ENDCASE
ENDLAMBDA)

* 5. Protected route: needs an Authorization header
loServer.Get("/api/secure/dashboard", LAMBDA(req, res)
	IF EMPTY(req.Header("authorization"))
		res.Status(401)
		res.Json([{"error": "Unauthorized: Missing Authorization header token."}])
	ELSE
		res.Json('{"accessGranted": true, "data": "Confidential VFP data stream loaded successfully."}')
	ENDIF
ENDLAMBDA)

* 6. Catch-all: every other GET / POST goes to the Process class.
*    The exact routes above win whatever the order, and "/" is not matched by "/*path".
loServer.Get("/*path", LAMBDA(req, res)
	RunProcess(req, res)
ENDLAMBDA)

loServer.Post("/*path", LAMBDA(req, res)
	RunProcess(req, res)
ENDLAMBDA)

* Start listening
TRY
	lnBound = loServer.Listen(lnPort)
	? "Listening on http://127.0.0.1:" + TRANSFORM(lnBound)
CATCH TO loException
	? "Server not started: " + loException.Message
ENDTRY

RETURN


*------------------------------------------------------------------------
*  Function: Hand a request to the Process class, answer 500 when it fails
*    Params: toRequest  - FoxDev request object
*            toResponse - FoxDev response object
*   Returns: None
*------------------------------------------------------------------------
PROCEDURE RunProcess(toRequest, toResponse)
	LOCAL loProcess, loException
	TRY
		loProcess = CREATEOBJECT("Process", toRequest, toResponse)
		loProcess.HandleRequest()
	CATCH TO loException
		WriteLog("Runtime error in Process: " + loException.Message, "ERROR")
		* A response that is already sent can not be written again
		IF NOT toResponse.Sent
			toResponse.Status(500)
			toResponse.Json([{"error": "Internal server execution error."}])
		ENDIF
	ENDTRY
ENDPROC

*------------------------------------------------------------------------
*  Function: Write a log line to the screen
*    Params: tcMessage - Text to log
*            tcLevel   - Level label, "INFO" when empty
*   Returns: None
*------------------------------------------------------------------------
PROCEDURE WriteLog(tcMessage, tcLevel)
	? TTOC(DATETIME()) + " [" + EVL(tcLevel, "INFO") + "] " + TRANSFORM(tcMessage)
ENDPROC

*------------------------------------------------------------------------
*  Function: Escape a value so it can be placed between quotes in JSON
*    Params: tcText - Value to escape
*   Returns: Character - escaped text
*------------------------------------------------------------------------
FUNCTION JsonEscape(tcText)
	LOCAL lcText
	lcText = TRANSFORM(tcText)
	lcText = STRTRAN(lcText, "\", "\\")
	lcText = STRTRAN(lcText, ["], [\"])
	lcText = STRTRAN(lcText, CHR(13), "\r")
	lcText = STRTRAN(lcText, CHR(10), "\n")
	lcText = STRTRAN(lcText, CHR(9), "\t")
	RETURN lcText
ENDFUNC
