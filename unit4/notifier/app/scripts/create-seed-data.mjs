import seedData from "./support/seeds.mjs";
import { query } from "../db/index.mjs";

async function main() {
  console.log("Writing seed data...");

  for (let pref of seedData.notificationPreferences) {
    await query(
      "INSERT INTO notification_preferences(user_id, address_type, address) VALUES($1, $2, $3)",
      [pref.user_id, pref.address_type, pref.address]
    );
  }
}

main();
