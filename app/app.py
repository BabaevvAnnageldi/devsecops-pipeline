"""Minimal Flask app used as the container-scan target for the pipeline."""

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def hello():
    return jsonify(message="Hello from the DevSecOps pipeline!")


@app.get("/health")
def health():
    # Used by the Docker HEALTHCHECK (and later by a load balancer).
    return jsonify(status="ok")


if __name__ == "__main__":
    # Local development only. In the container, gunicorn serves the app.
    app.run(host="127.0.0.1", port=8080)
