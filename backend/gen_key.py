import secrets

open(".env", "w").write("FLASK_SECRET_KEY=" + secrets.token_hex(32))
