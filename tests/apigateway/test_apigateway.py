from tlx.apigateway import proxy_response_handler, APIGException, require_valid_inputs
from tlx.dynamodb.aux import json_loads
from unittest import TestCase


class TestRequireFieldsFound(TestCase):

    def test_raises(self):
        msg = 'An exception should be raised if the required fields are not present'

        supplied = {'first': 1, 'nineteenth': 2}
        required = {'first', 'second'}

        with self.assertRaises(Exception, msg=msg):
            require_valid_inputs(supplied, required)

    def test_passes(self):
        msg = 'Nothing should be returned if the required fields are present'

        supplied = {'first': 1, 'nineteenth': 2}
        required = {'first'}

        self.assertIsNone(require_valid_inputs(supplied, required), msg)


class TestProxyResponseHandler(TestCase):
    apig_event = {'resource': 'yoyo', 'queryStringParameters': None, 'body': None}

    def test_malformed_event(self):
        msg = "An event without the schema of an API Gateway event should raise and exception"

        @proxy_response_handler
        def dummy_handler(event, context):
            print(f"received: {(event, context)}")

        with self.assertRaises(Exception, msg=msg):
            dummy_handler({}, {})

    def test_raised_exception(self):
        msg = 'A generic exception should return a PROXY RESPONSE with status 500'

        @proxy_response_handler
        def dummy_handler(event, context):
            raise Exception

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res['statusCode'], 500, msg)
        body = json_loads(res['body'])
        self.assertEqual(body["message"], 'Error', msg)

    def test_raised_APIGException(self):
        msg = 'Raising an APIGException should return a PROXY RESPONSE with the desired status'

        @proxy_response_handler
        def dummy_handler(event, context):
            raise APIGException('yoyo', code=404)

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res['statusCode'], 404, msg)
        body = json_loads(res['body'])
        self.assertEqual(body["message"], 'Error: yoyo', msg)

    def test_200(self):
        msg = 'An exception free execution of the handler should return 200 with the results'

        @proxy_response_handler
        def dummy_handler(event, context):
            return "Hallo"

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res['statusCode'], 200, msg)
        body = json_loads(res['body'])
        self.assertEqual(body["message"], 'Success', msg)
        self.assertEqual(body["response"], 'Hallo', msg)
