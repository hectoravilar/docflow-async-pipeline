<!--
  This is a simple webpage hosted in AWS S3 Bucket.
  This page should be a page should have a title "DreamSquad".
  This page should show a file comming from a API and display in the middle of
  the page.
  This page should use Jquery to request the API Value and should follow
  best practices for usability and responsive webpage.
  This page should have an template variable to use with terraform to substitute
  the api endpoint name.
-->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DreamSquad</title>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: Arial, sans-serif;
            display: flex;
            flex-direction: column;
            min-height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        header {
            background: rgba(0,0,0,0.2);
            padding: 20px;
            text-align: center;
        }
        h1 {
            color: white;
            font-size: 2.5rem;
        }
        main {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        #content {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            max-width: 600px;
            width: 100%;
            text-align: center;
        }
        #api-data {
            margin-top: 20px;
            font-size: 1.1rem;
            color: #333;
            word-wrap: break-word;
        }
        .loading { color: #667eea; }
        .error { color: #e74c3c; }
        @media (max-width: 768px) {
            h1 { font-size: 2rem; }
            #content { padding: 20px; }
        }
    </style>
</head>
<body>
    <header>
        <h1>DreamSquad</h1>
    </header>
    <main>
        <div id="content">
            <h2>API Response</h2>
            <div id="api-data" class="loading">Loading...</div>
        </div>
    </main>
    <script>
        $(document).ready(function() {
            const apiEndpoint = '${api_endpoint}';
            
            $.ajax({
                url: apiEndpoint,
                method: 'GET',
                timeout: 10000,
                success: function(data) {
                    $('#api-data').removeClass('loading')
                        .html('<strong>Random Number:</strong> ' + data.number);
                },
                error: function(xhr, status, error) {
                    $('#api-data').removeClass('loading').addClass('error')
                        .text('Error loading data: ' + (error || 'Unable to connect to API'));
                }
            });
        });
    </script>
</body>
</html>
