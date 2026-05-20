# YouTube Data API Setup Guide

## Quick Start (5 minutes)

### Step 1: Create GCP OAuth Credential

1. Open [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (or create one named `{brand}-youtube-automation`)
3. Go to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**
5. Choose **Desktop application**
6. Download JSON
7. Save to: `{brand-folder}/.gsai/youtube-oauth-credentials.json`

### Step 2: Register Redirect URI

1. In GCP Console, click your credential (the one you just created)
2. Under **Authorized redirect URIs**, add: `http://localhost:8089/callback`
3. Click **Save**

### Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Set **User Type** to **Internal** (if you own the channel)
3. Fill in required fields (app name, user support email, etc.)
4. Go to **Test users** → **Add users**
5. Add your email (the one who owns the YouTube channel)
6. Save

### Step 4: Enable YouTube Data API v3

1. Go to **APIs & Services** → **Library**
2. Search for **YouTube Data API v3**
3. Click **Enable**

### Step 5: Get Refresh Token

```bash
cd {brand-folder}/.scripts
export CREDS_DIR={brand-folder}/.gsai
python3 {path-to-skill}/youtube-oauth-localhost.py
```

- Opens browser automatically
- Click **Allow** to authorize
- Closed browser → token saved to `{CREDS_DIR}/youtube-tokens.json`
- Done! ✅

## Verify Setup

Test the automation:

```bash
export CREDS_DIR={brand-folder}/.gsai
{path-to-skill}/update-youtube-video.sh {video-id} \
  --description "Test description"
```

Expected output:
```
✅ Access token acquired
📥 Fetching current video metadata...
🔄 Updating video metadata...
✅ Video metadata updated successfully!
```

## Troubleshooting

### OAuth fails with "Invalid credentials"

**Cause**: Desktop app credential not created, or Web credential used instead

**Fix**:
- Confirm you created a **Desktop** application credential, not Web
- Delete and recreate if needed

### "redirect_uri_mismatch"

**Cause**: Redirect URI not registered in GCP OAuth settings

**Fix**:
1. GCP Console → Credentials → your credential
2. Add `http://localhost:8089/callback` to Authorized redirect URIs
3. Save
4. Re-run `youtube-oauth-localhost.py`

### "org_internal" error during auth

**Cause**: User not added as test user in OAuth consent screen

**Fix**:
1. GCP Console → OAuth consent screen → Test users
2. Add the email of the person who owns the YouTube channel
3. Click **Add** → **Save**
4. Re-run `youtube-oauth-localhost.py`

### Script can't find credentials file

**Cause**: `CREDS_DIR` not set or file path mismatch

**Fix**: Verify:
```
export CREDS_DIR={brand-folder}/.gsai
ls $CREDS_DIR/youtube-oauth-credentials.json
ls $CREDS_DIR/youtube-tokens.json
```

Also verify script is run from the correct directory.

### "insufficientPermissions"

**Cause**: OAuth scope set to `youtube.upload` instead of `youtube`

**Fix**:
1. Delete `$CREDS_DIR/youtube-tokens.json`
2. Re-run `python3 youtube-oauth-localhost.py` (will request `youtube` full scope)
3. Re-auth in browser
4. Retry script

## Reference

**Google Docs**:
- [YouTube Data API v3 Setup](https://developers.google.com/youtube/v3/getting-started)
- [OAuth 2.0 for Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Thumbnails: set Endpoint](https://developers.google.com/youtube/v3/docs/thumbnails/set)

**This Skill**:
- Main script: `update-youtube-video.sh`
- OAuth flow: `youtube-oauth-localhost.py`
- Full docs: `SKILL.md`
