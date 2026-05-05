import React from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {useAuthStore} from '@/features/auth/store';

// Screens (to be implemented per feature)
import LoginScreen from '@/features/auth/screens/LoginScreen';
import CalendarScreen from '@/features/calendar/screens/CalendarScreen';
import ListsScreen from '@/features/lists/screens/ListsScreen';
import WishlistsScreen from '@/features/wishlists/screens/WishlistsScreen';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

function MainTabs() {
  return (
    <Tab.Navigator>
      <Tab.Screen name="Calendar" component={CalendarScreen} />
      <Tab.Screen name="Lists" component={ListsScreen} />
      <Tab.Screen name="Wishlists" component={WishlistsScreen} />
    </Tab.Navigator>
  );
}

export default function RootNavigator() {
  const token = useAuthStore(s => s.token);

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{headerShown: false}}>
        {token ? (
          <Stack.Screen name="Main" component={MainTabs} />
        ) : (
          <Stack.Screen name="Login" component={LoginScreen} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
