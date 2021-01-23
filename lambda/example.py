import os

def lambda_handler(event, context):
    print('### Environment Variables')
    print(os.environ)
    print'### Event')
    print(event)