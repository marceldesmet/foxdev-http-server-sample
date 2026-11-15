*========================================================================
*      Class: Process
*    Purpose: Answer the requests of the catch-all route ( West Wind style )
* Attributes: oRequest - Object : FoxDev request object
*             oRespons - Object : FoxDev response object
*      Usage: loProcess = CREATEOBJECT("Process", req, res)
*             loProcess.HandleRequest()
*========================================================================
DEFINE CLASS Process
	oRequest = .NULL.	&& FoxDev request object
	oRespons = .NULL.	&& FoxDev response object

	*------------------------------------------------------------------------
	*  Function: Keep the request and the response of this hit
	*    Params: toRequest  - FoxDev request object
	*            toResponse - FoxDev response object
	*   Returns: None
	*------------------------------------------------------------------------
	FUNCTION Init(toRequest, toResponse)
		This.oRequest = toRequest
		This.oRespons = toResponse
	ENDFUNC

	*------------------------------------------------------------------------
	*  Function: Find the action of the request and run its method
	*   Returns: None
	*      Note: The action is ?action=name when given, else the script name of
	*            the path without folder and extension:
	*            /hello, /hello.jaz and /anything?action=hello all run SayHello
	*------------------------------------------------------------------------
	FUNCTION HandleRequest()
		LOCAL lcPath, lcAction

		* Rest of the path caught by the "/*path" route
		lcPath = LOWER(ALLTRIM(This.oRequest.Params("path")))
		IF LEFT(lcPath, 1) == "/"
			lcPath = SUBSTR(lcPath, 2)
		ENDIF
		IF RIGHT(lcPath, 1) == "/"
			lcPath = LEFT(lcPath, LEN(lcPath) - 1)
		ENDIF

		* Script name only: "shop/hello.jaz" gives "hello"
		IF RAT("/", lcPath) > 0
			lcPath = SUBSTR(lcPath, RAT("/", lcPath) + 1)
		ENDIF
		IF RAT(".", lcPath) > 1
			lcPath = LEFT(lcPath, RAT(".", lcPath) - 1)
		ENDIF

		lcAction = LOWER(EVL(This.oRequest.Query("action"), lcPath))

		DO CASE
			CASE lcAction == "hello"
				This.SayHello()
			OTHERWISE
				This.NotFound(lcAction)
		ENDCASE
	ENDFUNC

	*------------------------------------------------------------------------
	*  Function: Answer the hello action
	*   Returns: None
	*------------------------------------------------------------------------
	FUNCTION SayHello()
		This.oRespons.Send("Hello from devStudio at " + TTOC(DATETIME()))
	ENDFUNC

	*------------------------------------------------------------------------
	*  Function: Answer 404 for an action this class does not have
	*    Params: tcAction - Action asked by the request
	*   Returns: None
	*------------------------------------------------------------------------
	FUNCTION NotFound(tcAction)
		This.oRespons.Status(404)
		This.oRespons.Json('{"error": "Action not found.", "action": "' + JsonEscape(tcAction) + '"}')
	ENDFUNC

ENDDEFINE
