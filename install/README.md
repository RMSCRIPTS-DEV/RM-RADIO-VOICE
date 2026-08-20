# Installing rm-radios items (ox_inventory)

1. **Items** — open `ox_inventory/data/items.lua` and paste the three entries from
   [`items.lua`](./items.lua) into the `return { ... }` table.

2. **Images** — copy everything from [`images/`](./images) into `ox_inventory/web/images/`:

   | File | Item |
   |------|------|
   | `radio.png` | `radio` |
   | `shadow_module.png` | `shadow_module` |

   > `earpiece` has no bundled image yet — either add your own
   > `ox_inventory/web/images/earpiece.png`, or it'll render with ox_inventory's
   > fallback placeholder until you do.

3. **Resource name** — if you keep this resource's folder named `at-radio`, no
   further changes are needed. If you rename the folder (e.g. to `rm-radios`),
   update the `radio` item's `client.export` in `items.lua` to match
   (`"<your-folder-name>.use"`), since ox_inventory calls that export when the
   item is used.

4. **Restart** `ox_inventory` (and this resource) after editing `items.lua`.

That's it — no SQL migration needed, radios use `ox_inventory` metadata/stashes only.
