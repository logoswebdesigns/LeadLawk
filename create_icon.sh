#!/bin/bash

# Create a temporary HTML file with green background and logo
cat > temp_icon.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
<style>
body {
    margin: 0;
    padding: 0;
    background: #2ECC71;
    width: 1024px;
    height: 1024px;
    display: flex;
    align-items: center;
    justify-content: center;
}
.logo {
    width: 60%;
    height: 60%;
    filter: brightness(0) invert(1);
}
</style>
</head>
<body>
<img src="file:///Users/jacobanderson/Documents/GitHub/LeadLawk/assets/images/LeadLoq-logo.png" class="logo">
</body>
</html>
EOF

echo "HTML file created"