create type address_t as enum('email', 'sms', 'push');

CREATE TABLE notification_preferences (
    id bigserial PRIMARY KEY,
    user_id bigint NOT NULL,
    address_type address_t,
    address text,
    inserted_at timestamp(0) without time zone  NOT NULL DEFAULT CURRENT_TIMESTAMP(0)
);
