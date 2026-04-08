from flask import Flask, render_template, request, redirect, url_for, jsonify
from scanner import scan_subnet

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/subnet-scanner', methods=['GET', 'POST'])
def subnet_scanner():
    result = None
    error = None
    if request.method == 'POST':
        subnet = request.form.get('subnet')
        ports = request.form.getlist('ports')
        try:
            ports = [int(p) for p in ports]
            result = scan_subnet(subnet, ports)
        except Exception as e:
            error = str(e)
    return render_template('subnet_scanner.html', result=result, error=error)

if __name__ == '__main__':
    app.run(debug=True)