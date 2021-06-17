Debugging Funkwhale
===================

In order to track down errors its useful to provide as many information as possible. Usually pasting
the logs should be sufficient, but there are some tools for some deeper debugging.

Frontend Logs
-------------

Logs and errors written by the Frontend can be accessed with Firefox. When opening the website of
your Funkwhale instance, simply hit ``Ctlr + Shift + J``. Alternatively open the Firefox Menu and open
the Browser Console in the developers menu.

In the opening window you can see all the output. You can copy what you want to share or repeat the
failing operation to see what error occurs.

Backend Logs
------------

Depending on your setup you can see the logs from our API server in different ways.

Docker
^^^^^^

Simply run ``docker-compose logs --tail=100 api`` If you want continuous logs, add the ``f`` flag.

Quick install
^^^^^^^^^^^^^

To get the logs, run ``journalctl -xn -u funkwhale-server``

Profiling
---------

In order to find performance issues, its possible to run API requests with activated profiling. In
order to do this,  add ``funkwhale_api.common.middleware.ProfilerMiddleware`` to the environment
variable ``ADDITIONAL_MIDDLEWARES_BEFORE``

If enabled, simply add ``?prof`` to the request URL you want to profile. You should get an HTML-Report
of the running request.

Memory Tracing
--------------

Its possible to print memory traces for each API request to the API logs. In order to do this, add
``funkwhale_api.common.middleware.PymallocMiddleware`` to the environment variable
``ADDITIONAL_MODDLEWARES_BEFORE`` This adds a middleware which should not do anything by default.
Tracing can be activated by setting ``PYTHONTRACEMALLOC=1`` This might has some inpact on the
performance, please report how it goes. The Middleware now prints the top 25 memory allocations to
the API logs.
