# Milestone 8 — SEO Optimization

## What's new in the app
- Robots.txt optimization allowing crawling of the main landing page while disallowing `/overlay`, `/admin/`, `/admin`, `/api/`, `/webhooks/`, `/private/`, and `/dev/`.
- Meta robots control tags across all views (`index, follow...` for home, `noindex, nofollow` for `/overlay` and `/admin`).
- Canonical URL generation across all public views using the configured base URL.
- XML sitemap listing `/` (landing page) with dynamically computed lastmod.
- Descriptive, keyword-optimized titles and meta descriptions for public pages in Indonesian (`lang="id"`).
- Structured data (JSON-LD) for pages, including Organization and FAQPage structured data on `/`.
- SEO security headers (Strict-Transport-Security, X-Content-Type-Options: nosniff, X-Frame-Options: DENY) updated.
- Responsive viewports, mobile tap targets, and readable font sizes verified.
- Open Graph and Twitter Card tags added to head for social preview/visibility.
- Emerging AI search engine visibility supported via dynamic `llms.txt` index file and welcoming robots.txt rules for AI agents.
- Permanent 301 redirect for the legacy `/donate` route to the home route `/` preserving link equity.
- Contextual backlink integrations connecting the donation app to the streamer's personal website (`https://rizafahmi.com/`) on form description, payment success, and free thank-you screens, with target="_blank" safeties and UTM parameters.
- SameAs JSON-LD linkage mapping the Notable donation brand directly to Riza Fahmi's personal blog and socials.
- Navigation header links added to standard layout template to guide curious visitors to the streamer's home page.

## What was built

### SEO Plug and Dynamic Meta Tags
- Created a new [SEO Plug](file:///Users/riza/code/donatex/lib/notable_web/plugs/seo.ex) that runs on the browser pipeline to dynamically fetch the configured application base URL and populate connection assigns (`:meta_description`, `:meta_robots`, `:canonical_url`) based on the request path.
- Registered `NotableWeb.Plugs.SEO` inside the `:browser` pipeline in [router.ex](file:///Users/riza/code/donatex/lib/notable_web/router.ex).
- Updated [root.html.heex](file:///Users/riza/code/donatex/lib/notable_web/components/layouts/root.html.heex) to read these assigns and render description, robots, canonical links, Open Graph (og:type, og:title, og:description, og:url, og:site_name), and Twitter (twitter:card, twitter:title, twitter:description) tags.

### Dynamic JSON-LD Structured Data
- Injected Organization and FAQPage schemas as JSON-LD `<script type="application/ld+json">` blocks at the bottom of the landing page template in [donate_live.ex](file:///Users/riza/code/donatex/lib/notable_web/live/donate_live.ex). This includes structured details about the "Notable" brand and a fully descriptive Indonesian FAQ structure mapping landing page functionality.
- Extended the `Organization` JSON-LD schema with a `"sameAs"` array linking Notable directly to `https://rizafahmi.com/`, GitHub, and Twitter.

### Streamer Personal Website Linking (Backlinks & Copywriting)
- Added a link to Riza's personal website directly inside the landing page description copy on [donate_live.ex](file:///Users/riza/code/donatex/lib/notable_web/live/donate_live.ex).
- Integrated about links with custom UTM tracking (`utm_campaign=donation_page_thanks_tip` and `donation_page_thanks_free`) on both the tip and free feedback success pages to encourage post-donation traffic.
- Added a permanent `Tentang Riza` header navigation link to [layouts.ex](file:///Users/riza/code/donatex/lib/notable_web/components/layouts.ex) so users on administrative and public pages can easily find the streamer's background.
- Ensured all outgoing links use `target="_blank"` and `rel="noopener"` safeties.

### Static Asset Routing and Optimization
- Modified `static_paths/0` in [notable_web.ex](file:///Users/riza/code/donatex/lib/notable_web.ex) to ensure new static assets `sitemap.xml` and `llms.txt` are served directly by the web server.
- Wrote [robots.txt](file:///Users/riza/code/donatex/priv/static/robots.txt) allowing crawling of `/` but disallowing `/overlay` and all private/administrative endpoints, and linking to the sitemap.
- Created [sitemap.xml](file:///Users/riza/code/donatex/priv/static/sitemap.xml) with the landing page location, priority, update frequency, and modification date. Excluded `/overlay` from the sitemap to match the robots.txt disallow directive.
- Created [llms.txt](file:///Users/riza/code/donatex/priv/static/llms.txt) outlining the site name, description, and list of public pages for consumption by AI search agents.

### Security and Redirects
- Added `strict-transport-security` (`max-age=31536000; includeSubDomains`) to [security_headers.ex](file:///Users/riza/code/donatex/lib/notable_web/security_headers.ex) to pass Lighthouse technical trust signal gates.
- Updated the `/donate` redirection handler in [page_controller.ex](file:///Users/riza/code/donatex/lib/notable_web/controllers/page_controller.ex) to send a `301 Moved Permanently` status instead of a temporary `302 Found` status.

### Test Coverage and Assertions
- Created [static_seo_test.exs](file:///Users/riza/code/donatex/test/notable_web/controllers/static_seo_test.exs) to test successful delivery of static assets, HTTP header safety, and 301 redirect behavior.
- Added test cases in [donate_live_test.exs](file:///Users/riza/code/donatex/test/notable_web/live/donate_live_test.exs) and [overlay_live_test.exs](file:///Users/riza/code/donatex/test/notable_web/live/overlay_live_test.exs) to verify that metadata descriptions, robots index/noindex directives, canonical link tags, OG/Twitter tags, and JSON-LD schemas render properly.
- Updated [access_control_test.exs](file:///Users/riza/code/donatex/test/notable_web/features/access_control_test.exs) to verify `/admin` returns `noindex` and the correct canonical link header.
- Updated [page_controller_test.exs](file:///Users/riza/code/donatex/test/notable_web/controllers/page_controller_test.exs) to match the new 301 status assertions.
- Fixed mismatched checkboxes in [donor_qr_flow_test.exs](file:///Users/riza/code/donatex/test/notable_web/features/donor_qr_flow_test.exs) to resolve failures from previous local UI changes.

## Verification
- Comprehensive ExUnit and integration tests pass successfully (151 tests, 0 failures).
- Automated Dialyzer checks indicate 0 errors.
- Credo linter checks report no findings.
- Duplication checks detect 0 issues.
- Architecture policies pass without violations.
