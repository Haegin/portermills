import {useAuthStore} from '@/features/auth/store';

const SOCKET_URL = __DEV__
  ? 'ws://localhost:4000/socket'
  : 'wss://api.portermills.app/socket';

// Thin wrapper around the Phoenix WebSocket protocol.
// Each feature that needs real-time creates a channel via joinChannel().
// Replace with a proper Phoenix JS client package if complexity grows.

class PhoenixSocket {
  private ws: WebSocket | null = null;
  private channels: Map<string, (payload: unknown) => void> = new Map();
  private ref = 0;

  connect() {
    const token = useAuthStore.getState().token;
    this.ws = new WebSocket(`${SOCKET_URL}/websocket?token=${token}`);
    this.ws.onmessage = e => this.handleMessage(e);
    this.ws.onclose = () => setTimeout(() => this.connect(), 3000);
  }

  joinChannel(topic: string, onMessage: (payload: unknown) => void) {
    this.channels.set(topic, onMessage);
    this.send('phx_join', topic, {});
  }

  leaveChannel(topic: string) {
    this.channels.delete(topic);
    this.send('phx_leave', topic, {});
  }

  push(topic: string, event: string, payload: unknown) {
    this.send(event, topic, payload);
  }

  private send(event: string, topic: string, payload: unknown) {
    this.ws?.send(
      JSON.stringify([null, `${++this.ref}`, topic, event, payload]),
    );
  }

  private handleMessage(e: MessageEvent) {
    const [, , topic, event, payload] = JSON.parse(e.data);
    if (event !== 'phx_reply') {
      this.channels.get(topic)?.(payload);
    }
  }
}

export const socket = new PhoenixSocket();
