import React, {useState} from 'react';
import {View, Text, TextInput, Button, StyleSheet} from 'react-native';
import {api} from '@/api/client';
import {useAuthStore} from '../store';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const setAuth = useAuthStore(s => s.setAuth);

  async function requestLink() {
    setLoading(true);
    await api.post('/auth/magic-link', {email});
    setSent(true);
    setLoading(false);
  }

  if (sent) {
    return (
      <View style={styles.container}>
        <Text style={styles.heading}>Check your email</Text>
        <Text>Tap the link in the email to sign in.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.heading}>Portermills</Text>
      <TextInput
        style={styles.input}
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <Button title={loading ? 'Sending…' : 'Send magic link'} onPress={requestLink} disabled={loading} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1, justifyContent: 'center', padding: 24, gap: 16},
  heading: {fontSize: 28, fontWeight: '700'},
  input: {borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12},
});
