#!/usr/bin/env python3
"""
YouTube OAuth handler with localhost redirect.
Starts a local HTTP server, handles the OAuth callback, and exchanges code for refresh token.

Environment:
    CREDS_DIR   Directory containing youtube-oauth-credentials.json.
                Tokens will be saved here as youtube-tokens.json.
                Default: ./.gsai
"""

import json
import os
import sys
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlencode, parse_qs, urlparse
import requests
import time

CREDS_DIR = os.environ.get("CREDS_DIR", "./.gsai")
CREDS_FILE = os.path.join(CREDS_DIR, "youtube-oauth-credentials.json")
TOKENS_FILE = os.path.join(CREDS_DIR, "youtube-tokens.json")
PORT = 8089
REDIRECT_URI = f"http://localhost:{PORT}/callback"

class OAuthCallbackHandler(BaseHTTPRequestHandler):
    auth_code = None
    error = None

    def do_GET(self):
        parsed_url = urlparse(self.path)

        if parsed_url.path == "/callback":
            query_params = parse_qs(parsed_url.query)

            if "code" in query_params:
                OAuthCallbackHandler.auth_code = query_params["code"][0]
                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(b"<html><body><h1>Authorization successful!</h1><p>You can close this window.</p></body></html>")
                print(f"\n✅ Authorization code received: {OAuthCallbackHandler.auth_code[:20]}...")
            else:
                OAuthCallbackHandler.error = query_params.get("error", ["unknown"])[0]
                self.send_response(400)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(f"<html><body><h1>Error: {OAuthCallbackHandler.error}</h1></body></html>".encode())
                print(f"\n❌ Authorization failed: {OAuthCallbackHandler.error}")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        return  # Suppress default logging

def load_credentials():
    try:
        with open(CREDS_FILE) as f:
            creds = json.load(f)
        # Handle both web and installed (desktop) formats
        client_id = creds.get("web", {}).get("client_id") or creds.get("installed", {}).get("client_id")
        client_secret = creds.get("web", {}).get("client_secret") or creds.get("installed", {}).get("client_secret")

        if not client_id or not client_secret:
            print(f"❌ Could not extract client_id/client_secret from {CREDS_FILE}")
            sys.exit(1)

        return client_id, client_secret
    except FileNotFoundError:
        print(f"❌ Credentials file not found: {CREDS_FILE}")
        print("Set CREDS_DIR or place youtube-oauth-credentials.json in ./.gsai")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"❌ Invalid JSON in {CREDS_FILE}")
        sys.exit(1)

def start_oauth_flow():
    print("🔐 YouTube OAuth Flow (Localhost)")
    print("=" * 50)

    client_id, client_secret = load_credentials()

    # Build OAuth URL
    oauth_url = (
        "https://accounts.google.com/o/oauth2/v2/auth?"
        f"client_id={client_id}&"
        f"redirect_uri={REDIRECT_URI}&"
        "response_type=code&"
        "scope=https://www.googleapis.com/auth/youtube&"
        "access_type=offline"
    )

    print(f"\n📍 Starting local server on {REDIRECT_URI}")
    print(f"   Opening browser for authorization...\n")

    # Start HTTP server
    server = HTTPServer(("localhost", PORT), OAuthCallbackHandler)
    server_thread = None

    try:
        # Open browser
        webbrowser.open(oauth_url, new=1)

        # Handle requests with timeout
        server.timeout = 1
        timeout_start = time.time()
        timeout_seconds = 120  # 2 minute timeout

        while time.time() - timeout_start < timeout_seconds:
            server.handle_request()

            if OAuthCallbackHandler.auth_code:
                print(f"\n🔄 Exchanging code for refresh token...")

                # Exchange code for tokens
                token_response = requests.post(
                    "https://oauth2.googleapis.com/token",
                    data={
                        "client_id": client_id,
                        "client_secret": client_secret,
                        "code": OAuthCallbackHandler.auth_code,
                        "grant_type": "authorization_code",
                        "redirect_uri": REDIRECT_URI,
                    }
                )

                if token_response.status_code == 200:
                    tokens = token_response.json()

                    # Save tokens
                    os.makedirs(CREDS_DIR, exist_ok=True)
                    with open(TOKENS_FILE, "w") as f:
                        json.dump(tokens, f, indent=2)

                    print(f"✅ Tokens saved to: {TOKENS_FILE}")
                    print(f"\nRefresh Token: {tokens.get('refresh_token', '')[:50]}...")
                    print(f"Access Token: {tokens.get('access_token', '')[:50]}...")
                    print(f"\n✅ OAuth flow complete!")
                    return True
                else:
                    print(f"❌ Token exchange failed: {token_response.text}")
                    return False

            if OAuthCallbackHandler.error:
                print(f"❌ Authorization error: {OAuthCallbackHandler.error}")
                return False

        print(f"❌ Timeout waiting for authorization (2 minutes)")
        return False

    except KeyboardInterrupt:
        print("\n⚠️  OAuth flow cancelled by user")
        return False
    finally:
        server.server_close()

if __name__ == "__main__":
    success = start_oauth_flow()
    sys.exit(0 if success else 1)
