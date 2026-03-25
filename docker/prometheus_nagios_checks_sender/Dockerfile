FROM python:3.12
COPY send_nsca_x86_64 /usr/local/bin/send_nsca
RUN apt update && apt install -y libmcrypt4
WORKDIR /srv
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY main.py .
ENTRYPOINT ["/usr/local/bin/python", "/srv/main.py", "daemon"]
