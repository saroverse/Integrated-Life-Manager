"""
Extract Zepp apptoken + user_id WITHOUT logging out (logout invalidates the token).
Run once, copy values into backend/.env

Usage:
    cd backend && source venv/bin/activate && python3 extract_zepp_token.py
"""

from huami_token.zepp import ZeppSession

EMAIL = "***REMOVED***"
PASSWORD = "***REMOVED***"

session = ZeppSession(username=EMAIL, password=PASSWORD)
session.login()  # does NOT logout

print("\n=== Copy these into backend/.env ===")
print(f"ZEPP_APP_TOKEN={session.app_token}")
print(f"ZEPP_USER_ID={session.user_id}")
print("=====================================\n")
