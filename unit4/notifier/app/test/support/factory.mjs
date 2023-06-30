import { query } from "../../db/index.mjs";

export const createNotificationPreference = async (userId, type, address) => {
  const {
    rows: [createdPreference],
  } = await query(
    "INSERT INTO notification_preferences(user_id, address_type, address) VALUES($1, $2, $3) RETURNING *;",
    [userId, type, address]
  );

  return createdPreference;
};

export const buildNewMessageEvent = (userId) => {
  return {
    content: Buffer.from(
      JSON.stringify(
        {
          type: "new_message",
          channel_id: 1,
          user_id: userId,
          index: 1,
        },
        "utf8"
      )
    ),
    properties: { type: "new_message" },
  };
};
