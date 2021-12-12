/*
 * gRIP
 * Copyright (c) 2018 Alik Aslanyan <cplusplus256@gmail.com>
 * Copyright (C) The AMX Mod X Development Team.
 *
 *
 *    This program is free software; you can redistribute it and/or modify it
 *    under the terms of the GNU General Public License as published by the
 *    Free Software Foundation; either version 3 of the License, or (at
 *    your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful, but
 *    WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *    General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software Foundation,
 *    Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *    In addition, as a special exception, the author gives permission to
 *    link the code of this program with the Half-Life Game Engine ("HL
 *    Engine") and Modified Game Libraries ("MODs") developed by Valve,
 *    L.L.C ("Valve").  You must obey the GNU General Public License in all
 *    respects for all of the code used other than the HL Engine and MODs
 *    from Valve.  If you modify this file, you may extend this exception
 *    to your version of the file, but you are not obligated to do so.  If
 *    you do not wish to do so, delete this exception statement from your
 *    version.
 *
 */

/*
*    Some of the API definitions were taken from AMX Mod X. There are places, where I decided to do somethings differently.
*    Btw JSON implementation is designed to be 90% drop in replacement of AMX Mod X json.inc file.
*/

#if defined _grip_included
	#endinput
#endif
#define _grip_included

#pragma reqlib grip
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib grip
#endif


enum GripRequestType {
	GripRequestTypeGet = 0,
	GripRequestTypePost = 1,
	GripRequestTypePut = 2,
	GripRequestTypeDelete = 3
}

enum GripRequestCancellation {
	Invalid_GripRequestCancellation = 0,
}

enum GripRequestOptions {
	Empty_GripRequestOptions = -1,
	Invalid_GripRequestOptions = 0,
}

enum GripBody {
	Empty_GripBody = -1,
	Invalid_GripBody = 0,
}

enum GripJSONValue {
    Invalid_GripJSONValue = 0,
}

/*
 * JSON types
 */
enum GripJSONType
{
	GripJSONNull    = 1,
	GripJSONString  = 2,
	GripJSONNumber  = 3,
	GripJSONObject  = 4,
	GripJSONArray   = 5,
	GripJSONBoolean = 6,
	GripJSONError = 7,
};

enum GripResponseState {
	GripResponseStateCancelled = 1,
	GripResponseStateError = 2,
	GripResponseStateSuccessful = 3,
	GripResponseStateTimeout = 4,
}

enum GripHTTPStatus {
    GripHTTPStatusContinue = 100,
    GripHTTPStatusSwitchingProtocols = 101,
    GripHTTPStatusProcessing = 102,
    GripHTTPStatusOk = 200,
    GripHTTPStatusCreated = 201,
    GripHTTPStatusAccepted = 202,
    GripHTTPStatusNonAuthoritativeInformation = 203,
    GripHTTPStatusNoContent = 204,
    GripHTTPStatusResetContent = 205,
    GripHTTPStatusPartialContent = 206,
    GripHTTPStatusMultiStatus = 207,
    GripHTTPStatusAlreadyReported = 208,
    GripHTTPStatusImUsed = 226,
    GripHTTPStatusMultipleChoices = 300,
    GripHTTPStatusMovedPermanently = 301,
    GripHTTPStatusFound = 302,
    GripHTTPStatusSeeOther = 303,
    GripHTTPStatusNotModified = 304,
    GripHTTPStatusUseProxy = 305,
    GripHTTPStatusTemporaryRedirect = 307,
    GripHTTPStatusPermanentRedirect = 308,
    GripHTTPStatusBadRequest = 400,
    GripHTTPStatusUnauthorized = 401,
    GripHTTPStatusPaymentRequired = 402,
    GripHTTPStatusForbidden = 403,
    GripHTTPStatusNotFound = 404,
    GripHTTPStatusMethodNotAllowed = 405,
    GripHTTPStatusNotAcceptable = 406,
    GripHTTPStatusProxyAuthenticationRequired = 407,
    GripHTTPStatusRequestTimeout = 408,
    GripHTTPStatusConflict = 409,
    GripHTTPStatusGone = 410,
    GripHTTPStatusLengthRequired = 411,
    GripHTTPStatusPreconditionFailed = 412,
    GripHTTPStatusPayloadTooLarge = 413,
    GripHTTPStatusUriTooLong = 414,
    GripHTTPStatusUnsupportedMediaType = 415,
    GripHTTPStatusRangeNotSatisfiable = 416,
    GripHTTPStatusExpectationFailed = 417,
    GripHTTPStatusImATeapot = 418,
    GripHTTPStatusMisdirectedRequest = 421,
    GripHTTPStatusUnprocessableEntity = 422,
    GripHTTPStatusLocked = 423,
    GripHTTPStatusFailedDependency = 424,
    GripHTTPStatusUpgradeRequired = 426,
    GripHTTPStatusPreconditionRequired = 428,
    GripHTTPStatusTooManyRequests = 429,
    GripHTTPStatusRequestHeaderFieldsTooLarge = 431,
    GripHTTPStatusUnavailableForLegalReasons = 451,
    GripHTTPStatusInternalServerError = 500,
    GripHTTPStatusNotImplemented = 501,
    GripHTTPStatusBadGateway = 502,
    GripHTTPStatusServiceUnavailable = 503,
    GripHTTPStatusGatewayTimeout = 504,
    GripHTTPStatusHttpVersionNotSupported = 505,
    GripHTTPStatusVariantAlsoNegotiates = 506,
    GripHTTPStatusInsufficientStorage = 507,
    GripHTTPStatusLoopDetected = 508,
    GripHTTPStatusNotExtended = 510,
    GripHTTPStatusNetworkAuthenticationRequired = 511,
};

/**
 * Gets state of the response.
 *
 * @note    		This has nothing to do with HTTP status codes.
 *
 * @return			Returns current response state.
 */
native GripResponseState:grip_get_response_state();


/**
 * Gets HTTP status code of the response.
 *
 * @return			Returns current response state.
 */
native any:grip_get_response_status_code();

/**
 * Returns whether request exists/active. 
 *
 * @note 			This has nothing to do with HTTP status codes.
 *
 * @param request	Request handle.
 *  
 * @return			Returns current response state.
 */
native grip_is_request_active(GripRequestCancellation:request);

/**
 * Creates new body handle from string
 * 
 * @note 			Body should be destroyed with the relevant call.
 *
 * @param str		Zero terminated string from which body should be created
 *  
 * @return			Newly crated body handle
 */
native GripBody:grip_body_from_string(str[]);

/**
 * Creates new body handle from string
 *
 * @note 			        Body should be destroyed with the relevant call.
 *
 * @param str		        Zero terminated string from which body should be created
 * @param pretty            True to format pretty JSON string, false to not
 * @param recursion_limit   Limit of the internal recursion
 *
 * @return			        Newly crated body handle
 */
native GripBody:grip_body_from_json(GripJSONValue:value, bool:pretty = false, recursion_limit = 100);

/**
 * Destroys body handle
 *
 * @param body		Body to be destroyed
 *  
 * @noreturn
 */
native grip_destroy_body(GripBody:body);

/**
 * Starts sending of the request  
 * @note	The handle should look like:
 * 		public RequestHandler(const any: userData);
 *
 *
 * @param uri		Request URI. Supports TLS.
 * @param type		Request type which should be sended.
 * @param body		Reqeust body, can be either JSON or plaintext 
 * @param handler	A callback which will be called when request finishes execution
 * @param options	Request options containing HTTP headers, timeout and so on..
 * @param userData 	User data (can be datapack or anything)
 *  
 * @return		Cancellation handle.
 */
native GripRequestCancellation:grip_request(const uri[], GripBody:body, GripRequestType:type, const handler[], GripRequestOptions:options = Empty_GripRequestOptions, const any: userData = 0);

/**
 * Cancel sending of the request and receiving of response.  
 *
 * @param cancellation	Cancellation handle of the request.
 *  
 * @return		Request handle
 */
native grip_cancel_request(GripRequestCancellation:cancellation);

/**
 * Get current error description. Implementation defined.  
 *
 * @note There are certain AMXX limitations to maximum string sizes.  
 *
 * @param buffer	    Output buffer to which description should be written
 * @param buffer_size	Maximum length of the buffer.
 *  
 * @return              Number of cells written
 */
native grip_get_error_description(buffer[], buffer_size);

/**
 * Get current response body as string.
 *
 * @note There are certain AMXX limitations to maximum string sizes.  
 *
 * @param buffer	    Output buffer to which body should be written
 * @param buffer_size	Maximum length of the buffer.
 *  
 * @return              Number of cells written
 */
native grip_get_response_body_string(buffer[], buffer_size);

/**
 * Destroy this JSON value
 *
 * @param json_value	JSON Value to be destroyed.
 *
 * @noreturn
 */
native grip_destroy_json_value(GripJSONValue:grip_json_value);

/**
 * Create options with empty headers and some timeout.
 *
 * @note 		Options should be destroyed with the relevant call.
 *
 * @param timeout	timeout -1 to disable, >0 to enable timeout.
 *
 * @return 		Request options handle.
 */
native GripRequestOptions:grip_create_default_options(Float:timeout = -1.0);

/**
 * Destroy this options
 *
 * @noreturn
 */
native grip_destroy_options(GripRequestOptions:options);

/**
 * Add HTTP Header to this options.
 *.
 * @param options	Options to which header should be added
 * @param headerName 	Header name
 * @param headerValue	Header value
 *
 * @return 		Request options handle.
 */
native grip_options_add_header(GripRequestOptions:options, const headerName[], const headerValue[]);


/**
 * Create options with headers and some timeout.
 *
 * @note 		Options should be destroyed with the relevant call.
 *
 * @param headers	Array of header pairs.
 * @param headers_count	Count of the header pairs.
 * @param timeout	timeout -1 to disable, >0 to enable timeout.
 *
 * @return 		Request options handle.
 */
stock GripRequestOptions:grip_create_create_options(const headers[][2][], const headers_count, Float:timeout = -1.0) {
	new GripRequestOptions:options = grip_create_default_options(timeout);
	
	for(new i = 0; i < headers_count; ++i) {
		grip_options_add_header(options, headers[i][0], headers[i][1]);
	}
	
	return options;
}

/**
 * Parse current response body as JSON.
 *
 * @param buffer	            Output buffer to which possible error should be written
 * @param error_buffer_size	    Maximum length of the buffer.
 *
 *
 * @return                      JSON Value handle. If error occurred, returns invalid handle.
 */
native GripJSONValue:grip_json_parse_response_body(error_buffer[], const error_buffer_size);

/**
 * Parses string that contains JSON.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param string            String to parse
 * @param buffer	        Output buffer to which possible error should be written
 * @param error_buffer_size	Maximum length of the buffer.
 *
 * @return                  JSON value, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_parse_string(const string[], error_buffer[], const error_buffer_size);

/**
 * Parses file that contains JSON.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param string            String to parse
 *
 * @return                  JSON value, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_parse_file(const file[], error_buffer[], const error_buffer_size);

/**
 * Checks if the first value is the same as the second one.
 *
 * @param value1            JSON handle
 * @param value2            JSON handle
 *
 * @return                  True if they are the same, false otherwise
 * @error                   If passed value is not a valid handle
 */
native bool:grip_json_equals(const GripJSONValue:value1, const GripJSONValue:value2);

/**
 * Validates json by checking if object have identically named
 * fields with matching types.
 *
 * @note                    Schema {"name":"", "age":0} will validate
 *                          {"name":"Joe", "age":25} and {"name":"Joe", "age":25, "gender":"m"},
 *                          but not {"name":"Joe"} or {"name":"Joe", "age":"Cucumber"}.
 *
 * @note                    In case of arrays, only first value in schema
 *                          is checked against all values in tested array.
 *
 * @note                    Empty objects ({}) validate all objects,
 *                          empty arrays ([]) validate all arrays,
 *                          null validates values of every type.
 *
 * @param schema            JSON handle
 * @param value             JSON handle
 *
 * @return                  True if passed value is valid, false otherwise
 * @error                   If a schema handle or value handle is invalid
 */
native bool:grip_json_validate(const GripJSONValue:schema, const GripJSONValue:value);

/**
 * Gets value's parent handle.
 *
 * @note                  Parent's handle Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param value           JSON handle
 *
 * @return                Parent's handle
 */
// This method is wontfix, because of mixed value/ref semantics of json.inc
// native GripJSONValue:grip_json_get_parent(const GripJSONValue:value);

/**
 * Gets JSON type of passed value.
 *
 * @param value             JSON handle
 *
 * @return                  JSON type (GripJSONType constants)
 * @error                   If a value handle is invalid
 */
native GripJSONType:grip_json_get_type(const GripJSONValue:value);

/**
 * Inits an empty object.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_object();

/**
 * Inits an empty array.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_array();

/**
 * Inits string data.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param value             String that the handle will be initialized with
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_string(const value[]);

/**
 * Inits a number.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param value             Integer number that the handle will be initialized with
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_number(value);

/**
 * Inits a float number.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param value             Float number that the handle will be initialized with
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_float(Float:value);
#define grip_json_init_real(%1) grip_json_init_float(%1)

/**
 * Inits a boolean value.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param value             Boolean value that the handle will be initialized with
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_bool(bool:value);

/**
 * Inits a null.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 */
native GripJSONValue:grip_json_init_null();

/**
 * Creates deep copy of passed value.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param value             JSON handle to be copied
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 * @error                   If passed value is not a valid handle
 */
native GripJSONValue:grip_json_deep_copy(const GripJSONValue:value);

/**
 * Gets string data.
 *
 * @param value             JSON handle
 * @param buffer            Buffer to copy string to
 * @param maxlen            Maximum size of the buffer
 *
 * @return                  The number of cells written to the buffer
 * @error                   If passed value is not a valid handle
 */
native grip_json_get_string(const GripJSONValue:value, buffer[], maxlen);

/**
 * Gets a number.
 *
 * @param value             JSON handle
 *
 * @return                  Number
 * @error                   If passed value is not a valid handle
 */
native grip_json_get_number(const GripJSONValue:value);

/**
 * Gets a float number.
 *
 * @param value             JSON handle
 *
 * @return                  Real number
 * @error                   If passed value is not a valid handle
 */
#define grip_json_get_real(%1) grip_json_get_float(%1)
native Float:grip_json_get_float(const GripJSONValue:value);

/**
 * Gets a boolean value.
 *
 * @param value             JSON handle
 *
 * @return                  Boolean value
 * @error                   If passed value is not a valid handle
 */
native bool:grip_json_get_bool(const GripJSONValue:value);

/**
 * Gets a value from the array.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param array             Array handle
 * @param index             Position in the array (starting from 0)
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 * @error                   If passed handle is not a valid array
 */
native GripJSONValue:grip_json_array_get_value(const GripJSONValue:array, index);

/**
 * Gets string data from the array.
 *
 * @param array             Array handle
 * @param index             Position in the array (starting from 0)
 * @param buffer            Buffer to copy string to
 * @param maxlen            Maximum size of the buffer
 *
 * @return                  The number of cells written to the buffer
 * @error                   If passed handle is not a valid array
 */
native grip_json_array_get_string(const GripJSONValue:array, index, buffer[], buffer_size);

/**
 * Gets a number from the array.
 *
 * @param array             Array handle
 * @param index             Position in the array (starting from 0)
 *
 * @return                  The number as integer
 * @error                   If passed handle is not a valid array
 */
native grip_json_array_get_number(const GripJSONValue:array, index);

/**
 * Gets a real number from the array.
 *
 * @param array             Array handle
 * @param index             Position in the array (starting from 0)
 *
 * @return                  The number as float
 * @error                   If passed handle is not a valid array
 */
#define grip_json_array_get_real(%1, %2) grip_json_array_get_float(%1, %2)
native Float:grip_json_array_get_float(const GripJSONValue:array, index);

/**
 * Gets a boolean value from the array.
 *
 * @param array             Array handle
 * @param index             Position in the array (starting from 0)
 *
 * @return                  Boolean value
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_get_bool(const GripJSONValue:array, index);

/**
 * Gets count of the elements in the array.
 *
 * @param array             Array handle
 *
 * @return                  Number of elements in the array
 * @error                   If passed handle is not a valid array
 */
native grip_json_array_get_count(const GripJSONValue:array);

/**
 * Replaces an element in the array with value.
 *
 * @param array             Array handle
 * @param index             Position in the array to be replaced
 * @param value             JSON handle to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_replace_value(GripJSONValue:array, index, const GripJSONValue:value);

/**
 * Replaces an element in the array with string data.
 *
 * @param array             Array handle
 * @param index             Position in the array to be replaced
 * @param string            String to copy
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_replace_string(GripJSONValue:array, index, const string[]);

/**
 * Replaces an element in the array with number.
 *
 * @param array             Array handle
 * @param index             Position in the array to be replaced
 * @param number            Number to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_replace_number(GripJSONValue:array, index, number);

/**
 * Replaces an element in the array with real number.
 *
 * @param array             Array handle
 * @param index             Position in the array to be replaced
 * @param number            Real number to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_replace_float(GripJSONValue:array, index, Float:number);
#define grip_json_array_replace_real(%1, %2, %2) grip_json_array_replace_float(%1, %2, %3)

/**
 * Replaces an element in the array with boolean value.
 *
 * @param array             Array handle
 * @param index             Position in the array to be replaced
 * @param boolean           Boolean value to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_replace_bool(GripJSONValue:array, index, bool:boolean);

/**
 * Replaces an element in the array with null.
 *
 * @param array             Array handle
 * @param index             Position in the array to be replaced
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_replace_null(GripJSONValue:array, index);

/**
 * Appends a value in the array.
 *
 * @param array             Array handle
 * @param value             JSON handle to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_append_value(GripJSONValue:array, const GripJSONValue:value);

/**
 * Appends string data in the array.
 *
 * @param array             Array handle
 * @param string            String to copy
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_append_string(GripJSONValue:array, const string[]);

/**
 * Appends a number in the array.
 *
 * @param array             Array handle
 * @param number            Number to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_append_number(GripJSONValue:array, number);

/**
 * Appends a real number in the array.
 *
 * @param array             Array handle
 * @param number            Real number to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_append_float(GripJSONValue:array, Float:number);
#define grip_json_array_append_real(%1, %2, %3) grip_json_array_append_float(%1, %2, %3)

/**
 * Appends a boolean value in the array.
 *
 * @param array             Array handle
 * @param boolean           Boolean value to set
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_append_bool(GripJSONValue:array, bool:boolean);

/**
 * Appends a null in the array.
 *
 * @param array             Array handle
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_append_null(GripJSONValue:array);

/**
 * Removes an element from the array.
 *
 * @note                    Order of values in array may change during execution.
 *
 * @param array             Array handle
 * @param index             Position in the array (starting from 0)
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_remove(GripJSONValue:array, index);

/**
 * Removes all elements from the array.
 *
 * @param array             Array handle
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid array
 */
native bool:grip_json_array_clear(GripJSONValue:array);

/**
 * Gets a value from the object.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 * @error                   If passed handle is not a valid object
 */
native GripJSONValue:grip_json_object_get_value(const GripJSONValue:object, const name[], bool:dot_not = false);

/**
 * Gets string data from the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param buffer            Buffer to copy string to
 * @param maxlen            Maximum size of the buffer
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  The number of cells written to the buffer
 * @error                   If passed handle is not a valid object
 */
native grip_json_object_get_string(const GripJSONValue:object, const name[], buffer[], maxlen, bool:dot_not = false);

/**
 * Gets a number from the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  Number
 * @error                   If passed handle is not a valid object
 */
native grip_json_object_get_number(const GripJSONValue:object, const name[], bool:dot_not = false);

/**
 * Gets a real number from the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  Real number
 * @error                   If passed handle is not a valid object
 */
native Float:grip_json_object_get_float(const GripJSONValue:object, const name[], bool:dot_not = false);
#define grip_json_object_get_real(%1, %2, %3) grip_json_object_get_float(%1, %2, %3)

/**
 * Gets a boolean value from the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  Boolean value
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_get_bool(const GripJSONValue:object, const name[], bool:dot_not = false);

/**
 * Gets count of the keys in the object.
 *
 * @param object            Object handle
 *
 * @return                  Keys count
 * @error                   If passed handle is not a valid object
 */
native grip_json_object_get_count(const GripJSONValue:object);

/**
 * Gets name of the object's key.
 *
 * @param object            Object handle
 * @param index             Position from which get key name
 * @param buffer            Buffer to copy string to
 * @param maxlen            Maximum size of the buffer
 *
 * @return                  The number of cells written to the buffer
 * @error                   If passed handle is not a valid object
 */
native grip_json_object_get_name(const GripJSONValue:object, index, buffer[], maxlen);

/**
 * Gets a value at the specified position from the object.
 *
 * @note                    Needs to be destroyed using grip_destroy_json_value() native.
 *
 * @param object            Object handle
 * @param index             Position from which get key name
 *
 * @return                  JSON handle, Invalid_GripJSONValue if error occurred
 * @error                   If passed handle is not a valid object
 */
native GripJSONValue:grip_json_object_get_value_at(const GripJSONValue:object, index);

/**
 * Checks if the object has a value with a specific name and type.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param type              Type of value, if JSONError type will not be checked
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if has, false if not
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_has_value(const GripJSONValue:object, const name[], GripJSONType:type = GripJSONError, bool:dot_not = false);

/**
 * Sets a value in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 * @note                    It also removes the old value if any.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param value             JSON handle to set
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_set_value(GripJSONValue:object, const name[], const GripJSONValue:value, bool:dot_not = false);

/**
 * Sets string data in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 * @note                    It also removes the old value if any.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param string            String to copy
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_set_string(GripJSONValue:object, const name[], const string[], bool:dot_not = false);

/**
 * Sets a number in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 * @note                    It also removes the old value if any.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param number            Number to set
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_set_number(GripJSONValue:object, const name[], number, bool:dot_not = false);

/**
 * Sets a real number in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 * @note                    It also removes the old value if any.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param number            Real number to set
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_set_float(GripJSONValue:object, const name[], Float:number, bool:dot_not = false);
#define grip_json_object_set_real(%1, %2, %3, %4) grip_json_object_set_float(%1, %2, %3, %4)

/**
 * Sets a boolean value in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 * @note                    It also removes the old value if any.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param boolean           Boolean value to set
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_set_bool(GripJSONValue:object, const name[], bool:boolean, bool:dot_not = false);

/**
 * Sets a null in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 * @note                    It also removes the old value if any.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_set_null(GripJSONValue:object, const name[], bool:dot_not = false);

/**
 * Removes a key and its value in the object.
 *
 * @note                    If dot notation is used some values may be inaccessible
 *                          because valid names in JSON can contain dots.
 *
 * @param object            Object handle
 * @param name              Key name
 * @param dot_not           True to use dot notation, false to not
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_remove(GripJSONValue:object, const name[], bool:dot_not = false);

/**
 * Removes all keys and their values in the object.
 *
 * @param object            Object handle
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid object
 */
native bool:grip_json_object_clear(GripJSONValue:object);

/**
 * Gets size of serialization.
 *
 * @param value             JSON handle
 * @param pretty            True to count size for pretty format, false to not
 * @param null_byte         True to include null byte, false to not
 * @param recursion_limit   Limit of the internal recursion
 *
 * @return                  Size of serialized string
 * @error                   If passed handle is not a valid value
 */
native grip_json_serial_size(const GripJSONValue:value, bool:pretty = false, bool:null_byte = false, recursion_limit = 100);

/**
 * Copies serialized string to the buffer.
 *
 * @param value             JSON handle
 * @param pretty            True to format pretty JSON string, false to not
 * @param buffer            Buffer to copy string to
 * @param maxlen            Maximum size of the buffer
 * @param recursion_limit   Limit of the internal recursion
 *
 * @return                  The number of cells written to the buffer
 * @error                   If passed handle is not a valid value
 */
native grip_json_serial_to_string(const GripJSONValue:value, bool:pretty = false, buffer[], maxlen, recursion_limit = 100);

/**
 * Copies serialized string to the file.
 *
 * @param value             JSON handle
 * @param file              Path to the file
 * @param pretty            True to format pretty JSON string, false to not
 * @param recursion_limit   Limit of the internal recursion
 *
 * @return                  True if succeed, false otherwise
 * @error                   If passed handle is not a valid value
 */
native bool:grip_json_serial_to_file(const GripJSONValue:value, const file[], bool:pretty = false, recursion_limit = 100);