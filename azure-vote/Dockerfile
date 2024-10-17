  # Pull the base image
  FROM tiangolo/uwsgi-nginx:python3.12
  # Install depndencies
  WORKDIR /app

  # Copy the requirements file into the container
  COPY requirements.txt .
  RUN pip install flask 
  RUN pip install redis
  RUN pip install opencensus
  RUN pip install opencensus-ext-azure
  RUN pip install opencensus-ext-flask
  RUN pip install opencensus-ext-logging
  RUN pip install logging
  COPY . .

  # Expose the port the app runs on
  EXPOSE 5000

  # Define the command to run the application
  CMD ["python", "main.py"]