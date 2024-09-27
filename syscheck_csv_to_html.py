import csv
import sys

# Function to generate HTML report from CSV data
def generate_html_report(system_info_csv, log_csv, recommendation_csv):
    try:
        # Reading system info from the first CSV
        with open(system_info_csv, mode='r') as file:
            csv_reader = csv.DictReader(file)
            system_info = list(csv_reader)[0]

        # Reading log info from the second CSV
        with open(log_csv, mode='r') as file:
            csv_reader = csv.DictReader(file)
            log_info = list(csv_reader)

        # Reading recommendation info from the third CSV
        with open(recommendation_csv, mode='r') as file:
            csv_reader = csv.DictReader(file)
            recommendations = list(csv_reader)

    except (FileNotFoundError, Exception) as e:
        print(f"Error reading CSV files: {e}")
        sys.exit(1)

    # Extracting data from CSVs
    timestamp = system_info['timestamp']
    hostname = system_info['hostname']
    fqdn = system_info['fqdn']
    ip_address = system_info['ip_address']
    distro = system_info['distro']
    version = system_info['version']
    support_message = system_info['support_message']
    uptime_pretty = system_info['uptime_pretty']
    uptime_since = system_info['uptime_since']
    restart_needed = system_info['restart_needed'] == 'true'

    load_1_min = system_info['load_1_min']
    load_5_min = system_info['load_5_min']
    load_15_min = system_info['load_15_min']

    cpu_usage_percentage = system_info['cpu_usage_percentage']
    memory_usage_percentage = system_info['memory_usage_percentage']
    swap_usage_percentage = system_info['swap_usage_percentage']

    kernel_version = system_info['kernel_version']
    security_update_info = system_info['security_update_info']
    ntp_status = system_info['ntp_status']

    packages_upgradable = system_info['packages_upgradable']
    
    # Split package details into normal and security updates
    normal_updates = []
    security_updates = []
    package_details = system_info['package_details']
    packages = package_details.split(']')

    for package in packages:
        package = package.strip()
        if "security" in package.lower():
            security_updates.append(package)
        else:
            normal_updates.append(package)


    # HTML content creation
    html_content = f'''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>System Report - {hostname}</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                background-color: #f4f4f9;
                color: #333;
                margin: 0;
                padding: 20px;
            }}
            .report {{
                background-color: #fff;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                max-width: 800px;
                margin: 0 auto;
            }}
            h1, h2 {{
                text-align: center;
                font-weight: normal;
            }}
            .logo-section {{
                display: flex;
                justify-content: center;
                align-items: center;
                margin-bottom: 20px;
            }}
            .logo-section img {{
                width: 150px;
                margin: 0 20px;
            }}
            .introduction-section {{
                text-align: center;
                margin-bottom: 30px;
            }}
            .introduction-section h2 {{
                font-size: 22px;
                font-weight: 600;
                margin-bottom: 10px;
            }}
            .introduction-section p {{
                font-size: 15px;
                color: #555;
            }}
            .section {{
                background-color: #fff;
                padding: 20px;
                margin-bottom: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }}
            .section h3 {{
                font-size: 18px;
                color: #007bff;
                margin-bottom: 10px;
            }}
            table {{
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 10px;
            }}
            th, td {{
                padding: 10px;
                border: 1px solid #ddd;
            }}
            th {{
                background-color: #f9f9f9;
                font-weight: bold;
            }}
            .collapsible {{
                background-color: #007bff;
                color: white;
                cursor: pointer;
                padding: 10px;
                text-align: left;
                border: none;
                outline: none;
                width: 100%;
                font-size: 16px;
                margin-bottom: 10px;
                display: flex;
                align-items: center;
                justify-content: space-between;
            }}
            .arrow {{
                transition: transform 0.3s ease;
            }}
            .content {{
                padding: 0 18px;
                display: none;
                overflow: hidden;
                background-color: #f9f9f9;
                border: 1px solid #ddd;
                margin-top: 10px;
            }}
            .rotate {{
                transform: rotate(90deg);
            }}
            .priority-high {{
                color: white;
                background-color: #d9534f;
                padding: 3px 8px;
                border-radius: 3px;
                font-size: 12px;
                margin-right: 10px;
                display: inline-block;
            }}
            .priority-medium {{
                color: white;
                background-color: #f0ad4e;
                padding: 3px 8px;
                border-radius: 3px;
                font-size: 12px;
                margin-right: 10px;
                display: inline-block;
            }}
            .priority-low {{
                color: white;
                background-color: #5cb85c;
                padding: 3px 8px;
                border-radius: 3px;
                font-size: 12px;
                margin-right: 10px;
                display: inline-block;
            }}
        </style>
        <script>
            function toggleContent(contentId, arrowId) {{
                var content = document.getElementById(contentId);
                var arrow = document.getElementById(arrowId);
                if (content.style.display === "none") {{
                    content.style.display = "block";
                    arrow.classList.add("rotate");
                }} else {{
                    content.style.display = "none";
                    arrow.classList.remove("rotate");
                }}
            }}
        </script>
    </head>
    <body>

    <div class="report">
        <!-- Logo Section -->
        <div class="logo-section">
            <img src="data:image/png;base64,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" alt="Firma Logosu">
            <img src="data:image/png;base64,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" alt="Müşteri Logosu">
        </div>

        <!-- Introduction Section -->
        <div class="introduction-section">
            <h2>Welcome to the System Report</h2>
            <p>This report provides detailed information on the system status, updates, and recommendations.</p>
        </div>

        <h1>System Report - {hostname}</h1>

        <!-- General Information Section -->
        <div class="section">
            <h3>General Information</h3>
            <p><strong>Timestamp:</strong> {timestamp}</p>
            <p><strong>Hostname:</strong> {hostname}</p>
            <p><strong>FQDN:</strong> {fqdn}</p>
            <p><strong>IP Address:</strong> {ip_address}</p>
            <p><strong>Distribution Version:</strong> {distro} {version}</p>
            <p><strong>Support Message:</strong> {support_message}</p>
            <p><strong>System Uptime:</strong> {uptime_pretty} (since {uptime_since})</p>
            <p><strong>Restart Needed:</strong> {"Yes" if restart_needed else "No"}</p>
        </div>

        <!-- Load Average Section -->
        <div class="section">
            <h3>Load Average</h3>
            <table>
                <thead>
                    <tr>
                        <th>1 Minute</th>
                        <th>5 Minutes</th>
                        <th>15 Minutes</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>{load_1_min}</td>
                        <td>{load_5_min}</td>
                        <td>{load_15_min}</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <!-- CPU, Memory, and Swap Usage Section -->
        <div class="section">
            <h3>CPU, Memory, and Swap Usage</h3>
            <p><strong>CPU Usage:</strong> {cpu_usage_percentage}%</p>
            <p><strong>Memory Usage:</strong> {memory_usage_percentage}%</p>
            <p><strong>Swap Usage:</strong> {swap_usage_percentage}%</p>
        </div>

        <!-- Kernel Info Section -->
        <div class="section">
            <h3>Kernel Info</h3>
            <p><strong>Kernel Version:</strong> {kernel_version}</p>
            <p><strong>Security Update Info:</strong> {security_update_info}</p>
            <p><strong>NTP Status:</strong> {ntp_status}</p>
        </div>

        <!-- Available Updates Section -->
        <div class="section">
            <h3>Available Updates</h3>
            <p><strong>Upgradable Packages:</strong> {packages_upgradable}</p>
            <button class="collapsible" onclick="toggleContent('packageDetails', 'arrowPackage')">View Detailed Package List <span id="arrowPackage" class="arrow">▶</span></button>
            <div id="packageDetails" class="content">
                <h4>Regular Updates</h4>
                {''.join([f'{package}<br>' for package in normal_updates])}

                <h4>Security Patches</h4>
                {''.join([f'{package}<br>' for package in security_updates])}
            </div>
        </div>

        <!-- Recommendations Section -->
        <div class="section">
            <h3>Recommendations</h3>
            <ul>
    '''

    for recommendation in recommendations:
        priority_class = recommendation['priority'].lower()  # Convert priority to lowercase for CSS class
        html_content += f"<li><span class='priority-{priority_class}'>Priority: {recommendation['priority'].capitalize()}</span><strong>{recommendation['category'].capitalize()}:</strong> {recommendation['message']}</li>"

    # Log section with toggle functionality
    html_content += '''
            </ul>
        </div>

        <!-- Log Issues Section -->
        <div class="section">
            <h3>Log Issues</h3>
            <button class="collapsible" onclick="toggleContent('logDetails', 'arrowLog')">View Log Details <span id="arrowLog" class="arrow">▶</span></button>
            <div id="logDetails" class="content">
                <table>
                    <thead>
                        <tr>
                            <th>Log File</th>
                            <th>Category</th>
                            <th>Line Number</th>
                            <th>Message</th>
                            <th>Count</th>
                        </tr>
                    </thead>
                    <tbody>
    '''

    # Add log details to the report
    for log in log_info:
        html_content += f'''
            <tr>
                <td>{log['log_file']}</td>
                <td>{log['category']}</td>
                <td>{log['line_number']}</td>
                <td>{log['message']}</td>
                <td>{log['count']}</td>
            </tr>
        '''

    # Closing the HTML content
    html_content += '''
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    </body>
    </html>
    '''

    # Save the HTML content to a file using the hostname in the filename
    filename = f'{hostname}_system_report.html'
    with open(filename, 'w') as file:
        file.write(html_content)

    print(f"HTML report generated: {filename}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python script.py <system_info_csv> <log_csv> <recommendation_csv>")
        sys.exit(1)

    system_info_csv = sys.argv[1]
    log_csv = sys.argv[2]
    recommendation_csv = sys.argv[3]

    generate_html_report(system_info_csv, log_csv, recommendation_csv)
