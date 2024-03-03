##############################################
# Simple short script to create CSV file from XLSX file
# The ERP software at work, does the export in XLSX or TXT format.
# To upload to MySQL database I need to convert it to CSV. 
##############################################

import pandas as pd

# Replace 'file_name.xlsx' with your Excel file path
input_excel_path = 'file_name.xlsx'

# Replace 'file_name.csv' with your desired output text file path
output_txt_path = 'file_name.csv'

# Read the Excel file into a pandas DataFrame
data = pd.read_excel(input_excel_path)

# Save the DataFrame to a CSV (comma-separated values) file
# specifying the encoding parameter to maintain encoding
data.to_csv(output_txt_path, sep=',', index=False, encoding='utf-8-sig')

print(f"Conversion from '{input_excel_path}' to '{output_txt_path}' completed successfully.")
