import React from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';

export default function ListsScreen() {
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.heading}>Lists</Text>
      <View style={styles.placeholder}>
        <Text>Shopping & packing lists — to be built</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1},
  heading: {fontSize: 24, fontWeight: '700', padding: 16},
  placeholder: {flex: 1, alignItems: 'center', justifyContent: 'center'},
});
