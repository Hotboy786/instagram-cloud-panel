# Instagram Cloud Panel

A standalone shared workspace. This package does not modify the Madara panel, its production database, the TikTok service, or the Windows Instagram app.

## Behavior

- Visiting the site wakes the web service. Signing in to the panel does not launch Chromium.
- Opening an account starts one isolated Chromium profile. Switching accounts saves the previous profile before opening the next.
- **Save profile & release** closes Chromium and uploads an encrypted snapshot to private Supabase Storage. Panel sign-out also saves first.
- Closing the tab sends a save-and-stop request. If that request is missed, a 90-second client lease and 20-second cleanup loop save and stop the browser in about 90–110 seconds after the last successful request. Hidden tabs stop preview requests, so they eventually sleep too.
- On the next opening, the service restores the latest encrypted snapshot, including its cookies and browser storage. Instagram may expire or revoke those sessions and ask for login or verification again.
- One person controls the shared browser at a time. An explicit Take control button can transfer control. This deployment must use exactly one server instance and one Uvicorn worker: leases are held in process memory.
- The account list has no fixed app limit. Storage capacity, upload limits and hosting quotas still apply.
- Paste an Instagram post/Reel link and choose **Open link**. It opens only in the currently selected account. All social actions remain manual.

The preview is an interactive screenshot refreshed approximately every two seconds, not a smooth video/audio stream. Video may be playing in the cloud browser, but the panel displays occasional frames. Uploads and audio are not supported by this preview.

## Deploy separately, step by step

### 1. GitHub

1. Extract this ZIP.
2. Create a new repository named `instagram-cloud-panel`. This keeps the existing Madara repository unchanged.
3. Upload the **contents** of the `instagram-cloud-panel` folder into the repository root. `Dockerfile`, `app.py`, `requirements.txt`, and `static/` must appear at the repository root.
4. Commit the uploaded source. Upload no real `.env`, Windows `data` folders, passwords, cookies or profile archives.

### 2. Supabase test project

1. Open the separate test project, or create a dedicated Instagram project. Leave the production Madara project unchanged.
2. In SQL Editor, run all of `supabase.sql`. It creates only `public.instagram_accounts` and the private `instagram-profiles` bucket.
3. Ensure Data API is enabled and `public` is an exposed schema.
4. Under Authentication → Users, create your panel user with an email and a new panel password. Confirm the user. This password is for this panel, not Instagram.
5. Copy the project URL, legacy `anon` key and server-only `service_role` key from the same project. Keep the service-role key private.

### 3. Generate a profile encryption key

In Windows PowerShell, run these lines. Copy the generated output directly to Render; do not send it in chat or upload it to GitHub.

```powershell
$profileBytes = New-Object byte[] 32
$profileRng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$profileRng.GetBytes($profileBytes)
[Convert]::ToBase64String($profileBytes).Replace('+','-').Replace('/','_')
$profileRng.Dispose()
```

Keep this key in a private password manager. Use the same key for every deployment of this service. Replacing or losing it makes existing profile backups unreadable.

### 4. Render

1. Choose **New → Web Service** and connect the new `instagram-cloud-panel` GitHub repository.
2. Set name to `instagram-cloud-panel` (or another available name), runtime to **Docker**, branch to your uploaded branch, and instance type to **Free**.
3. Leave Root Directory blank when `Dockerfile` is at the repository root. If you uploaded the enclosing folder instead, use its actual path as Root Directory.
4. Use `/health` as the health-check path. The Dockerfile supplies the start command. Do not add multiple workers or replicas.
5. Add these environment variables before deploying:

| Key | Value |
| --- | --- |
| `SUPABASE_URL` | Your test project's HTTPS URL |
| `SUPABASE_ANON_KEY` | The same project's legacy anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | The same project's private service_role key |
| `PROFILE_ENCRYPTION_KEY` | The generated key from step 3 |
| `ALLOWED_EMAILS` | Your panel user's email |

Leave `ALLOWED_EMBED_ORIGINS` unset for the standalone site. Never put the service-role or profile encryption keys into Vercel frontend variables. This service hosts its own frontend; Vercel is not required.

6. Deploy and open the Render URL. `/health` should return `configured: true` once all required settings are present; this confirms settings are present, not that Supabase credentials are valid.
7. Sign in with the panel user, add one Instagram account, and sign in to Instagram manually inside the preview. Complete any verification yourself.
8. Click **Save profile & release**. Confirm the account shows a backup time before leaving. Reopen it and confirm whether Instagram restored the login.
9. Test again after a Render restart. Only add the remaining accounts after this test succeeds.

Your current Windows app data is not imported. Sign in once per account in the cloud browser.

### 5. Add your brother later

Create his confirmed panel user in the same Supabase project and add his email to `ALLOWED_EMAILS`, separated by a comma. He signs in using his own panel password at the same Render URL. Both allowed users have access to the same account list and saved profiles. Do not send him the server keys or encrypted archives.

## Sleep and persistence

Render Free sleeps after 15 minutes without inbound traffic and wakes on a request, usually with a cold-start delay. There are no uptime-robot calls or keep-alive jobs in this package. Leave external uptime monitors disabled if you want the service to sleep.

Official reference: https://render.com/docs/free

Render's local filesystem is ephemeral. Only successful Supabase snapshots survive restarts or sleep. Always use Save & release after the first login or important work. Abrupt host termination or a failed upload can lose changes since the last successful snapshot; the app retains failed uploads locally for retry while that instance survives.

Free hosting memory, shared monthly running-hour quotas, and storage limits may still prevent reliable Chromium use. The package is not a guarantee that cloud Instagram login will be accepted. No CAPTCHA bypass, automatic re-login, automated likes, or account rotation is included.

## Verification

Install `requirements.txt`, then run:

```text
python -m unittest discover -s tests -v
```

Tests mock cloud/browser interactions. They cover encrypted backup round trips, archive traversal rejection, access restrictions, save-before-switch failure handling, latest-snapshot restoration, ownership and disconnect cleanup, startup without a browser, and Instagram link validation. A real Render/Supabase/Instagram deployment still requires the smoke test above.
