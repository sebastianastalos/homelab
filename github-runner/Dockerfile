FROM myoung34/github-runner:latest

RUN pip3 install --break-system-packages git+https://github.com/truenas/api_client.git@TS-25.10.0 2>/dev/null || \
    pip3 install --break-system-packages git+https://github.com/truenas/api_client.git 2>/dev/null || true
