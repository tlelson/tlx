import sys
import logging
import functools
from tlx.dynamodb.aux import json_dumps
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def proxy_response_handler(func=None, running_local=False, quiet=True):
    """ A Decorator for lambda functions. The function to be decorated by have two positional arguments
        (event, context) as any lambda handler would.  Decorating your handler allows you to write idomatic python
        using returns and raising exception.  This handler catches and formats them as proxy response objects
        suitable for APIG.

        This function does the following:
            - prints the received `event` to the debug logs
            - Sets the generic error response
            - Ensures raised exceptions are caught and formatted correctly
            - Unforseen errors are NOT propogated back to the user
            - Forseen exceptions ARE propogated back to the user in the `response.message` field
                (Developers should raise APIGException if they want the message to return)

        The decorated function should return data that can be converted to JSON.  This can be a list, dict, string,
        number or boolean.  It should raise a APIGException if the user wants to return the error message and modify
        the return code.  Otherwise all other Exceptions are returned as 500 response codes without a detailed error
        message.

        Set running_local=True if we're running locally (eg. we're not imported/running on AWS Lambda),
        and Python stack traces will show when exceptions are raised.
        Example usage: @proxy_response_handler(running_local=__name__=="__main__")

        Set quiet=True (default) to suppress all error output including stack traces (eg. for Prod deployments)
    """
    if not func:
        return functools.partial(proxy_response_handler, running_local=running_local, quiet=quiet)

    @functools.wraps(func)
    def wrapper(*axgs):
        # Setup default response
        response = {
            "statusCode": 500,
            "body": {
                "message": "Error",
                "response": {},
            },
        }

        def setup_error_response(msg, code=None):
            logger.error(msg)
            response["body"]["message"] = msg
            if code:
                response["statusCode"] = code

        # If the event is not from the apigateway a KeyError may be raised
        # and intentionally not caught
        event, context = axgs[0], axgs[1]
        logger.info('event: {}'.format(json_dumps(event)))
        logger.debug("Received '{resource}' request with params: {queryStringParameters} and body: {body}".format(**event))

        try:  # to get successfull execution
            response["body"]["response"] = func(event, context)
            response["body"]["message"] = "Success"
            response["statusCode"] = 200

        # if not, format appropriately for proxy integration
        except APIGException as e:
            setup_error_response("Error: {e}".format(e=e), e.code)
        except Exception as e:  # Unforseen Exception arose
            if quiet:
                pass  # Returns generic error response for production deployment
            elif running_local:
                sys.stderr.write("Local run detected, showing Python Exception stack trace:\n")
                raise e
            else:
                setup_error_response("Error: {e}".format(e=e))  # For remote testing

        # Final preparation for http reponse
        if response["body"]["response"] is None:
            del response["body"]["response"]
        response["body"] = json_dumps(response["body"])
        logger.info("Returning repsonse: {response}".format(**locals()))
        return response
    return wrapper


def require_valid_inputs(supplied, required):
    """ Returns None if `supplied` is a superset of `required`.  Raises `APIGException` with
        error code 400 if not.
        Bothe params must be an iterable.
    """

    try:
        missing_parameters = set(required).difference(supplied)
    except TypeError:
        # supplied is not itterable
        missing_parameters = required

    if missing_parameters:
        msg = "Invalid input parameters: {missing_parameters}".format(**locals())
        raise APIGException(msg, code=400)


class APIGException(Exception):
    """
        Differentiate these exceptions from general ones so that we can return the exception message.
        (We don't want to return general exception messages)

        e.g to return a HTTP 402 with a custom message, raise an exception like so:
        `raise APIGException('Payment required', code=402)`
    """
    def __init__(self, message, code=500):
        self.code = code
        Exception.__init__(self, message)
