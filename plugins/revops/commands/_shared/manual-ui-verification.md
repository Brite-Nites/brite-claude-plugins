# Shared reference — manual UI verification after a Salesforce deploy

Not a command. Included by reference from `/revops:preview-changes` Phase 5.

Some classes of defect are only observable in the Lightning UI: cached flexipage
definitions, the Kanban Group By cache (BC-4734), IndexedDB staleness, and
Dynamic Forms FLS paths. `sf` reports a clean deploy for every one of them. The
user is the sensor here, which is why this stays manual.

Present the sections below that apply to what was just deployed. Substitute
`{dev-org}` with the resolved target org.

---

Open `{dev-org}` in your browser and verify any UI that the deploy touched. Work through each section that applies to what you just deployed.

---

### 1. Flexipage changes

**Symptom:** Page still shows the old layout after deploy — hard-refresh (`Cmd+Shift+R`) didn't help.

**Why it happens:** Lightning caches flexipage definitions in IndexedDB (`actions` database). A hard-refresh clears the HTTP cache but not IndexedDB. The stale definition persists until the DB is cleared or you log out/in.

**Fix (fastest) — clear IndexedDB via DevTools:**
1. Open the page that looks wrong.
2. Open Chrome DevTools (`Cmd+Option+I`) → **Application** tab → **Storage** → **IndexedDB** → `actions`.
3. Right-click `actions` → **Delete database**, or run in the Console tab: `indexedDB.deleteDatabase("actions")`
4. Hard-refresh (`Cmd+Shift+R`). The page re-fetches the definition from the server.

**Fix (alternative) — log out/in:**
1. Click your avatar (top-right) → **Log Out**.
2. Log back in. Session re-init clears the IndexedDB state.

---

### 2. Kanban Group By dropdown

**Symptom:** A new picklist field you deployed doesn't appear as an option in the Kanban **Group By** dropdown.

**Why it happens:** Salesforce caches the list of fields eligible for Kanban grouping server-side. A new picklist field isn't added to that cache until it appears on at least one page layout for the object — the layout assignment is the cache invalidation trigger.

**Fix:**
1. In `{dev-org}`: **Setup → Object Manager → [Object] → Page Layouts → [any layout] → Edit**.
2. Drag the new picklist field onto the layout anywhere (it doesn't need to stay there permanently).
3. **Save** the layout.
4. Re-deploy the affected layout to flush the cache (scope to just the changed layout — Brite default is PR-diff-scoped, see [BC-11030](https://linear.app/brite-nites/issue/BC-11030)): `sf project deploy start --source-dir force-app/main/default/layouts/<Object>-<Layout>.layout-meta.xml --target-org {dev-org} --json`
5. Return to the Kanban view — the field should now appear in Group By.

---

### 3. Dynamic Forms — custom fields not rendering

**Symptom:** A custom field you deployed is missing from a record page that uses Dynamic Forms, even when logged in as a System Administrator.

**Why it happens:** Dynamic Forms respects FLS (Field-Level Security) even for System Administrators when `runInMode` is `SystemModeWithoutSharing` or the page is component-driven. A field with no FLS grant on any permission set won't render in Dynamic Forms.

**Fix:**
1. Identify which permission sets need access. Per `brite-salesforce/CLAUDE.md` §Permissions, find sets via:
   ```bash
   grep -l "{Object}\." force-app/main/default/permissionsets/*.permissionset-meta.xml
   ```
   Exclude migration-scoped / one-time sets (e.g. `HubSpot_Migration`).
2. Add `<fieldPermissions>` to each relevant permset XML:
   ```xml
   <fieldPermissions>
       <editable>true</editable>
       <field>ObjectName__c.FieldName__c</field>
       <readable>true</readable>
   </fieldPermissions>
   ```
3. Re-deploy, then hard-refresh the record page.

---

### 4. Screen Flows — not running after deploy

**Symptom:** A screen flow you deployed doesn't launch, or the Launch button is missing.

**Why it happens:** Salesforce deploys flows as **Draft** status by default, even if the source XML has `<status>Active</status>`. The deploy always resets to Draft on first land.

**Fix:**
1. In `{dev-org}`: **Setup → Flows → [Flow Name]**.
2. Click **Activate** (top-right of the flow detail page).
3. Confirm — the flow status changes to **Active**.

If the flow was previously active in that org and this deploy is an update (not a first deploy), it will have been deactivated. Re-activate the same way.

**Note:** Record-triggered flows (`RecordAfterSave`, `RecordBeforeSave`) are also deployed as Draft. Same fix applies.
