# SideKick PS Website - Technical Reference

## Live URLs

| Purpose | URL |
|---------|-----|
| **Landing Page** | https://sidekick.zoom-photo.uk/ |
| **Features** | https://sidekick.zoom-photo.uk/#features |
| **Pricing** | https://sidekick.zoom-photo.uk/#pricing |
| **How It Works** | https://sidekick.zoom-photo.uk/#how-it-works |
| **FAQ** | https://sidekick.zoom-photo.uk/#faq |

## Hosting & Deployment

| Item | Details |
|------|---------|
| **Hosting Platform** | GitHub Pages |
| **Repository** | https://github.com/GuyMayer/SideKick_PS |
| **Branch** | `main` |
| **Published From** | `/docs` folder |
| **Custom Domain** | sidekick.zoom-photo.uk |
| **HTTPS** | Enabled (via GitHub Pages) |

## DNS Configuration

Configure these records at your domain registrar (e.g., GoDaddy, Cloudflare):

### Option A: CNAME (Recommended for subdomains)
```
Type: CNAME
Host: sidekick
Points to: guymayer.github.io
TTL: 3600 (or Auto)
```

### Option B: A Records (For apex domain)
If using the root domain, point to GitHub's IPs:
```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

## Files Structure

```
SideKick_PS/
└── docs/
    ├── index.html          # Main landing page
    ├── CNAME               # Custom domain config (contains: sidekick.zoom-photo.uk)
    ├── images/             # Screenshots and assets (to be added)
    │   ├── favicon.png
    │   ├── hero-screenshot.png
    │   ├── invoice-sync.png
    │   ├── payment-calculator.png
    │   └── ghl-integration.png
    └── WEBSITE_TECHNICAL_INFO.md  # This file
```

## LemonSqueezy Integration

| Item | Details |
|------|---------|
| **Store** | zoomphoto.lemonsqueezy.com |
| **Product** | SideKick PS Monthly Subscription |
| **Checkout URL** | https://zoomphoto.lemonsqueezy.com/buy/234060d4-063d-4e6f-b91b-744c254c0e7c |
| **Pricing** | £14.99/month (billed annually at £149/year) |
| **Trial** | 14 days (via LemonSqueezy - requires CC upfront) |

## Updating the Website

### Quick Edit
1. Edit `docs/index.html` in VS Code
2. Commit: `git add docs/index.html && git commit -m "Update website"`
3. Push: `git push origin main`
4. Wait 1-2 minutes for GitHub Pages to deploy

### From Terminal
```powershell
cd C:\Stash\SideKick_PS
# Make your changes to docs/index.html
git add docs/
git commit -m "Your commit message"
git push origin main
```

### Verify Deployment
- Check https://github.com/GuyMayer/SideKick_PS/actions for deployment status
- Clear browser cache or use incognito to see changes

## Troubleshooting

### Site Not Updating
1. Check GitHub Actions for deployment errors
2. Clear browser cache (Ctrl+Shift+R)
3. Wait 5-10 minutes for CDN propagation

### Custom Domain Not Working
1. Verify CNAME file exists in `docs/` folder with content: `sidekick.zoom-photo.uk`
2. Check DNS propagation: https://dnschecker.org
3. In GitHub repo Settings > Pages, ensure custom domain is set

### HTTPS Certificate Issues
- GitHub auto-provisions SSL after DNS is verified
- Can take up to 24 hours for initial setup
- Check "Enforce HTTPS" is enabled in repo Settings > Pages

## Key Dependencies

| Component | Version/Details |
|-----------|-----------------|
| **Tailwind CSS** | CDN (latest via cdn.tailwindcss.com) |
| **Fonts** | Google Fonts - Inter |
| **Icons** | Inline SVG (Heroicons style) |

## Trademarks Notice (in footer)

> ProSelect® is a registered trademark of TimeExposure Software Inc. GoHighLevel is a trademark of HighLevel Inc. SideKick PS is an independent automation tool developed by Zoom Photography Studios Ltd and is not affiliated with, endorsed by, or sponsored by TimeExposure Software Inc. or HighLevel Inc.

## Contact

- **Support Email**: guy@zoom-photo.uk
- **Company**: Zoom Photography Studios Ltd

---
*Last updated: February 2026*
