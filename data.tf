data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "./lambda/example.py"
  output_path = "./lambda/example.zip"
}