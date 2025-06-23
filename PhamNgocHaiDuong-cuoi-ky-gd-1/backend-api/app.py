import logging
from flask_cors import CORS
from flask import Flask, request, jsonify
from prometheus_flask_exporter import PrometheusMetrics
app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO)
tasks = []
next_id = 1
metrics = PrometheusMetrics(app, path="/metrics")
@app.route('/api')
def api():
    return {"message": "Hello API"}
@app.route('/tasks', methods=['GET'])
def get_tasks():
    return jsonify(tasks)

@app.route('/tasks', methods=['POST'])
def add_task():
    global next_id
    data = request.json
    task = {"id": next_id, "title": data.get("title", "")}
    tasks.append(task)
    next_id += 1
    return jsonify(task), 201

@app.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    data = request.json
    for task in tasks:
        if task["id"] == task_id:
            task["title"] = data.get("title", task["title"])
            return jsonify(task)
    return jsonify({"error": "Not found"}), 404

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    global tasks
    tasks = [t for t in tasks if t["id"] != task_id]
    return jsonify({"result": "ok"})

@app.after_request
def after_request(response):
    log = f"{request.method} {request.path} {response.status_code}"
    app.logger.info(log)
    return response
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
