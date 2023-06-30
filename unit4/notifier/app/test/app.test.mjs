import supertest from "supertest";
import app, { handleMessageConsume, handleNewMessageEvent } from "../index.mjs";
import { query } from "../db/index.mjs";
import {
  createNotificationPreference,
  buildNewMessageEvent,
} from "./support/factory.mjs";
import sinon from "sinon";

describe("notifier service API", () => {
  afterEach(async () => {
    await query("TRUNCATE notification_preferences;");
  });

  describe("GET /health", () => {
    it("should return OK", async () => {
      await supertest(app).get("/health").expect(200);
    });
  });
});

describe("handling a new message from the AMQP broker", () => {
  let channel, logSpy;
  beforeEach(() => {
    if (logSpy) logSpy.restore();
    logSpy = sinon.spy(console, "log");
    channel = { ack: sinon.stub() };
  });

  afterEach(() => {
    console.log.restore();
  });

  it("should forward the message to the right handler", async () => {
    const handlerSpy = sinon.spy();
    await handleMessageConsume(channel, buildNewMessageEvent(1), {
      new_message: handlerSpy,
    });

    sinon.assert.calledOnce(handlerSpy);
  });

  it("should ack after processing by the handler", async () => {
    const handlerSpy = sinon.spy();
    await handleMessageConsume(channel, buildNewMessageEvent(1), {
      new_message: handlerSpy,
    });

    sinon.assert.calledOnce(handlerSpy);
    sinon.assert.calledOnce(channel.ack);
  });

  it("should log that it dropped the message if it is not a handled type", async () => {
    const handlerSpy = sinon.spy();

    await handleMessageConsume(channel, buildNewMessageEvent(1), {
      nonmatching_event_type: handlerSpy,
    });

    sinon.assert.notCalled(handlerSpy);
    sinon.assert.calledWith(
      logSpy,
      "Message with unhandled `type` received: new_message. Ignoring..."
    );
  });

  it("should ack the message even if it was dropped", async () => {
    const handlerSpy = sinon.spy();
    await handleMessageConsume(channel, buildNewMessageEvent(1), {
      nonmatching_event_type: handlerSpy,
    });

    sinon.assert.notCalled(handlerSpy);
    sinon.assert.calledOnce(channel.ack);
  });
});

describe("handling a new_message event on the `chat_queue`", () => {
  let logSpy, user_one_sms, user_two_sms, user_two_email;

  beforeEach(async () => {
    logSpy = sinon.spy(console, "log");
    user_one_sms = await createNotificationPreference(1, "sms", "11111");
    user_two_sms = await createNotificationPreference(2, "sms", "22222");
    user_two_email = await createNotificationPreference(
      2,
      "email",
      "leatherjackets@guy.brush"
    );
  });

  afterEach(async () => {
    console.log.restore();
    await query("TRUNCATE notification_preferences;");
  });

  it("should log that notifications were sent to all addresses for the user", async () => {
    await handleNewMessageEvent(
      JSON.stringify({
        type: "new_message",
        channel_id: "1",
        user_id: 1,
        index: 6,
        participant_ids: [1, 2],
      })
    );

    // The first call to console log just spits out the raw message
    sinon.assert.calledWith(
      logSpy.secondCall,
      `Sending notification of new message via ${user_two_sms.address_type} to ${user_two_sms.address}`
    );

    sinon.assert.calledWith(
      logSpy.thirdCall,
      `Sending notification of new message via ${user_two_email.address_type} to ${user_two_email.address}`
    );
  });

  it("should log that no notifications were sent if the user has no preferences", async () => {
    await handleNewMessageEvent(
      JSON.stringify({
        type: "new_message",
        channel_id: "1",
        user_id: 1,
        index: 6,
        participant_ids: [1, 3], // user with id three has no preferences set in the `beforeEach`
      })
    );

    // Called once and only once - this is the message printing the raw message
    sinon.assert.calledOnce(logSpy);
  });
});
