------------------------
----- [ Services ] -----
local HttpService = game:GetService("HttpService")

-----------------------
----- [ Modules ] -----
local Log = require("../Helpers/Log")
local bitwriter = require("./bitwriter")
local Configuration = require("../Helpers/Configuration")

------------------------
----- [ Varibles ] -----

----------------------
----- [ Tables ] -----
local Serializer = {}

----------------------
----- [ Types ] -----
export type HttpHeaders = {
	[string]: string,
}

export type decoded_http_res = {
	ok: boolean,
	status: number,
	headers: HttpHeaders,
	data: { [string]: any }?,
	error: string?,
}

export type RawHttpResponse = {
	StatusCode: number,
	StatusMessage: string,
	Headers: HttpHeaders,
	Body: string?,
	Success: boolean,
}

------------------------
----- [ Functions ] ----

local function CreateHttpRes(raw_http: RawHttpResponse, data: { [string]: any }?): decoded_http_res
	return {
		ok = raw_http.StatusCode >= 200 and raw_http.StatusCode < 300,
		status = raw_http.StatusCode,
		headers = raw_http.Headers,
		data = data,
		error = nil,
	}
end

local function CreateMalformedHTTPres(
	ok: boolean,
	status: number,
	headers: HttpHeaders,
	data: { [string]: any }?,
	error: string?
): decoded_http_res
	return {
		ok = ok,
		status = status,
		headers = headers,
		data = data,
		error = error,
	}
end

--[[
    @Function: Serializer.read(raw_http: RawHttpResponse)
     Decodes the data to the apporiate langauge format (Luau)

    @Options (arguments):
     raw_http: RawHttpResponse (preferably not nil)
]]
--
function Serializer.read(raw_http: RawHttpResponse): decoded_http_res
	--- Verifying & type checking
	if not raw_http then
		return CreateMalformedHTTPres(false, 0, {}, nil, "no http result passed!")
	end

	if not raw_http.Body or #raw_http.Body <= 0 then
		return CreateMalformedHTTPres(false, raw_http.StatusCode, raw_http.Headers, nil, "Empty response")
	end

	if raw_http.Body:find("<!DOCTYPE") or raw_http.Body:find("<html") then
		raw_http.Body = nil
		return CreateMalformedHTTPres(
			false,
			raw_http.StatusCode,
			raw_http.Headers,
			nil,
			"caught html content, unable to read html content mentioning !DOCTYPE or contains <html in it's body"
		)
	end

	if raw_http.Body:find("Cannot GET") or raw_http.Body:find("Cannot POST") then
		raw_http.Body = nil
		return CreateMalformedHTTPres(false, raw_http.StatusCode, raw_http.Headers, nil, "No route handler")
	end

	if #raw_http.Body > Configuration.MAX_BODY_SIZE then
		raw_http.Body = nil
		return CreateMalformedHTTPres(
			false,
			raw_http.StatusCode,
			raw_http.Headers,
			nil,
			"Response body exceeds maximum size of " .. Configuration.MAX_BODY_SIZE .. " bytes"
		)
	end

	--- Varibles
	local successfully_decoded, data = pcall(HttpService.JSONDecode, HttpService, raw_http.Body)

	raw_http.Body = nil

	--- Checking the result of the data
	if not successfully_decoded then
		return CreateMalformedHTTPres(
			false,
			raw_http.StatusCode,
			raw_http.Headers,
			nil,
			"HttpService failed to decode json to luau compactable content"
		)
	end

	--- Checking if the backend returned an error in the body
	if data and data.error then
		return CreateMalformedHTTPres(
			raw_http.StatusCode >= 200 and raw_http.StatusCode < 300,
			raw_http.StatusCode,
			raw_http.Headers,
			data,
			data.error
		)
	end

	return CreateHttpRes(raw_http, data)
end

--[[
    @Function: Serializer.write(content: {[string]: any})
     Converts a Luau table into JSON, immediately writes the
     bytes into FastStack and nils the loose string so it
     never exists as a loose variable in memory longer than
     necessary

    @Options (Arguments):
     content: {[string]: any}

    @Returns:
     boolean, bitwriter.BitObject?
]]
--
function Serializer.write(content: { [string]: any }): (boolean, bitwriter.BitObject?)
	--- Verifying & type checking
	if not content or type(content) ~= "table" then
		return Log("error", "write() expects a table")
	end

	--- Varibles
	local successfully_encoded: boolean, Err: string?
	local ZIP: bitwriter.BitObject

	successfully_encoded, Err = pcall(function(...)
		--- Varibles
		local payload = HttpService:JSONEncode(content)

		-- We'll now establish if the Json payload fit's the configuration prequesites
		-- if it does we'll write it to the buffer otherwise we'll return a error and release it from memory
		if #payload > Configuration.MAX_BODY_SIZE then
			Log(
				"error",
				`Serializer.write() payload size({#payload}) excceeds the limit of {Configuration.MAX_BODY_SIZE}`
			)
		end

		-- writing the payload to a buffer
		ZIP = bitwriter.CreateStack(#payload)
		ZIP:WriteString(payload)
	end)

	if not successfully_encoded then
		return false, nil
	end

	ZIP:SetCursorAt(0)

	return true, ZIP
end

return Serializer
