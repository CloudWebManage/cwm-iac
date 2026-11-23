FROM python:3.15.2@sha256:46837ed3105db0029b6d656816185c6258e3b39690532fb782428e0a5fd76182
COPY send_nsca_x86_64 /usr/local/bin/send_nsca
RUN apt update && apt install -y libmcrypt4
WORKDIR /srv
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY main.py .
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["/usr/local/bin/python", "/srv/main.py", "daemon"]
