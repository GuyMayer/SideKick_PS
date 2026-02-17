import markdown

# Read markdown file
with open(r'c:\Stash\SideKick_PS\docs\ProSelect_GHL_Field_Mapping.md', 'r', encoding='utf-8') as f:
    md_content = f.read()

# Convert to HTML with tables extension
html_content = markdown.markdown(md_content, extensions=['tables', 'fenced_code'])

# Wrap in full HTML document with styling
html_doc = """<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>ProSelect to GoHighLevel Field Mapping Guide</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 900px; margin: 40px auto; padding: 20px; line-height: 1.6; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        h3 { color: #7f8c8d; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; font-size: 14px; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #3498db; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        code { background-color: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: Consolas, monospace; }
        pre { background-color: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; }
        blockquote { border-left: 4px solid #3498db; margin: 20px 0; padding-left: 15px; color: #666; }
        hr { border: none; border-top: 1px solid #ddd; margin: 30px 0; }
        ul { padding-left: 25px; }
        @media print { body { max-width: 100%; margin: 0; } }
    </style>
</head>
<body>
""" + html_content + """
</body>
</html>"""

# Write HTML file
output_path = r'c:\Stash\SideKick_PS\docs\ProSelect_GHL_Field_Mapping.html'
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(html_doc)

print(f'HTML created: {output_path}')
print('Open in browser and press Ctrl+P to print/save as PDF')
