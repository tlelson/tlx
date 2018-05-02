# TLX

Often needed utilities and code.

This is a namespace package.  Submodules sometimes share dependencies but are often used/deployed in to production seperately.


## Light install
If this grows too large it may become a namespace packge so that parts can be installed easily. But until that time if you need a tool and only that tool, say for a deployment to AWS lambda or GCP App engine, then:

1.  Do a local install without dependencies:
`pip install --no-deps -t package/location/ tlx`
2.  Remove all the things you dont need
3.  Run your project and install the dependencies as above until it works.
