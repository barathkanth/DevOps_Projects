// send_order.js
import { EventBridgeClient, PutEventsCommand } from "@aws-sdk/client-eventbridge";

const client = new EventBridgeClient({ region: process.env.AWS_REGION || "us-east-1" });

async function send(order) {
  const params = {
    Entries: [
      {
        Source: "com.myapp.orders",
        DetailType: "OrderCreated",
        Detail: JSON.stringify(order),
        EventBusName: process.env.EVENT_BUS || "orders-bus"
      }
    ]
  };
  const cmd = new PutEventsCommand(params);
  const res = await client.send(cmd);
  console.log("PutEvents result:", res);
}

const sampleOrder = {
  orderId: `order-${Date.now()}`,
  customerId: "cust-123",
  amount: 199.99,
  currency: "USD",
  items: [{ sku: "ABC", qty: 1 }],
  createdAt: new Date().toISOString()
};

send(sampleOrder).catch(console.error);
