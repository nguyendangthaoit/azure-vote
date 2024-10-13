from flask import Flask, request, render_template
import os
import redis
import socket
import logging
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.log_exporter import AzureEventHandler
from opencensus.ext.azure.metrics_exporter import new_metrics_exporter
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.samplers import ProbabilitySampler
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.trace.tracer import Tracer
from opencensus.stats import stats as stats_module

# Application Insights Configuration
INSTRUMENTATION_KEY = 'InstrumentationKey=3190bc01-3062-4144-80b4-8d759d721b5c;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=27808f8a-f2d8-47a8-b2b9-c14721d98e57'

# Initialize Flask App
app = Flask(__name__)

# Logging Configuration
# logger = logging.getLogger(__name__)
# logger.addHandler(AzureLogHandler(connection_string=INSTRUMENTATION_KEY))
# logger.setLevel(logging.INFO)

logger = logging.getLogger(__name__)
handler = AzureLogHandler(connection_string=INSTRUMENTATION_KEY)
handler.setFormatter(logging.Formatter('%(traceId)s %(spanId)s %(message)s'))
logger.addHandler(handler)

# Logging custom Events
logger.addHandler(AzureEventHandler(connection_string=INSTRUMENTATION_KEY))

# Metrics Exporter
# metrics_exporter = new_metrics_exporter(connection_string=INSTRUMENTATION_KEY)

stats = stats_module.stats
view_manager = stats.view_manager
exporter = new_metrics_exporter(
enable_standard_metrics=True,
connection_string=INSTRUMENTATION_KEY)
view_manager.register_exporter(exporter)

# Tracing Configuration
tracer = Tracer(
    exporter=AzureExporter(connection_string=INSTRUMENTATION_KEY),
    sampler=ProbabilitySampler(1.0)  # 100% sampling rate
)

# Middleware for automatic tracing
middleware = FlaskMiddleware(
    app,
    exporter=AzureExporter(connection_string=INSTRUMENTATION_KEY),
    sampler=ProbabilitySampler(1.0)
)

# Redis Connection
r = redis.Redis()

# Load configurations from environment or config file
app.config.from_pyfile('config_file.cfg')

button1 = os.getenv('VOTE1VALUE', app.config['VOTE1VALUE'])
button2 = os.getenv('VOTE2VALUE', app.config['VOTE2VALUE'])
title = os.getenv('TITLE', app.config['TITLE'])

# Change title to hostname if required
if app.config['SHOWHOST'] == "true":
    title = socket.gethostname()

# Initialize Redis counters if not already set
if not r.get(button1):
    r.set(button1, 0)
if not r.get(button2):
    r.set(button2, 0)


@app.route('/', methods=['GET', 'POST'])
def index():
    """Handles voting page display and POST votes"""
    if request.method == 'GET':
        with tracer.span(name="Load Voting Page"):
            vote1 = r.get(button1).decode('utf-8')
            vote2 = r.get(button2).decode('utf-8')
            logger.info('Page loaded with votes', extra={
                'custom_dimensions': {
                    'Cats Vote': vote1,
                    'Dogs Vote': vote2
                }
            })
        return render_template("index.html", value1=int(vote1), value2=int(vote2), button1=button1, button2=button2, title=title)

    elif request.method == 'POST':
        if request.form['vote'] == 'Reset':
            # Reset votes
            r.set(button1, 0)
            r.set(button2, 0)

            with tracer.span(name="Reset Votes"):
                logger.info('Votes reset', extra={
                    'custom_dimensions': {
                        'Cats Vote': 0,
                        'Dogs Vote': 0
                    }
                })

            vote1 = r.get(button1).decode('utf-8')
            vote2 = r.get(button2).decode('utf-8')
            return render_template("index.html", value1=int(vote1), value2=int(vote2), button1=button1, button2=button2, title=title)

        else:
            # Increment vote in Redis
            vote = request.form['vote']
            r.incr(vote, 1)

            # Get the updated vote counts
            vote1 = r.get(button1).decode('utf-8')
            vote2 = r.get(button2).decode('utf-8')

            # Log the vote increment and add trace for business events
            with tracer.span(name=f"Vote for {vote}"):
                logger.info(f'{vote} vote incremented', extra={
                    'custom_dimensions': {
                        vote: r.get(vote).decode('utf-8')
                    }
                })

            # Track custom events for 'Dogs' and 'Cats' button clicks
            if vote == button2:
                # Custom event telemetry for Dog vote
                logger.info('Dog button clicked', extra={
                    'custom_dimensions': {
                        'Dog Vote': r.get(button2).decode('utf-8')
                    }
                })

            if vote == button1:
                # Custom event telemetry for Cat vote
                logger.info('Cat button clicked', extra={
                    'custom_dimensions': {
                        'Cat Vote': r.get(button1).decode('utf-8')
                    }
                })

            return render_template("index.html", value1=int(vote1), value2=int(vote2), button1=button1, button2=button2, title=title)


if __name__ == "__main__":
    app.run()  # Use this for local development
