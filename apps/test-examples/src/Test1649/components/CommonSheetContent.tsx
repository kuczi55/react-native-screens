import * as React from 'react';
import {
  Button,
  View,
  TextInput,
  Text,
} from 'react-native';

import * as jotai from 'jotai';

import {
  allowedDetentsAtom,
  cornerRadiusAtom,
  expandsWhenScrolledToEdgeAtom,
  grabberVisibleAtom,
  isAdditionalContentVisibleAtom,
  largestUndimmedDetentAtom,
  selectedDetentIndexAtom
} from '../state';
import { NavProp } from '../types';
import { useNavigation } from '@react-navigation/native';

export default function CommonSheetContent(): React.JSX.Element {
  const navigation = useNavigation<NavProp>()?.navigation;

  const [radius, setRadius] = jotai.useAtom(cornerRadiusAtom);
  const [detents, setDetents] = jotai.useAtom(allowedDetentsAtom);
  const [largestUndimmedDetent, setLargestUndimmedDetent] = jotai.useAtom(
    largestUndimmedDetentAtom,
  );
  const [isGrabberVisible, setIsGrabberVisible] =
    jotai.useAtom(grabberVisibleAtom);
  const [shouldExpand, setShouldExpand] = jotai.useAtom(
    expandsWhenScrolledToEdgeAtom,
  );
  const [selectedDetentIndex, setSelectedDetentIndex] = jotai.useAtom(
    selectedDetentIndexAtom,
  );
  const isAdditionalContentVisible = jotai.useAtomValue(
    isAdditionalContentVisibleAtom,
  );

  const ref = React.useRef<TextInput>(null);

  function nextDetentLevel(currentDetent: number): number {
    return 0;
  }

  return (
    <View style={[{ backgroundColor: 'lightgreen' }]}>
      <View style={{ paddingTop: 10 }}>
        <TextInput
          style={{
            backgroundColor: 'lightblue',
            paddingHorizontal: 5,
            margin: 5,
            borderRadius: 5,
          }}
          placeholder="123"
          inputMode="numeric"
          ref={ref}
        />
        <Button
          title="Tap me for the first screen"
          onPress={() => navigation.navigateDeprecated('First')}
        />
        <Button
          title="Tap me for the second screen"
          onPress={() => navigation.navigateDeprecated('Second')}
        />
        <Button
          title="Tap me for the third screen / blur"
          onPress={() => {
            navigation.navigate('NestedStack');
          }}
        />
        <Button
          title="Tap me for goBack"
          onPress={() => {
            navigation.goBack();
          }}
        />
        <Button
          title="Tap me to open another sheet"
          onPress={() => {
            if (ref.current) {
              // ref.current.blur();
              navigation.navigate('AnotherSheetScreen');
            }
          }}
        />
        <Button
          title="Change the corner radius"
          onPress={() => {
            const newRadius = radius >= 150 ? -1.0 : radius + 50;
            setRadius(newRadius);
            navigation.setOptions({
              sheetCornerRadius: newRadius,
            });
          }}
        />
        <Text>radius: {radius}</Text>
        <Button
          title="Change detent level"
          onPress={() => {
            const newDetentLevel = nextDetentLevel(
              detents[selectedDetentIndex],
            );
            setSelectedDetentIndex(newDetentLevel);
            // navigation.setOptions({
            //   sheetAllowedDetents: newDetentLevel,
            // });
          }}
        />
        <Text>Allowed detents: {detents}</Text>
        <Button
          title="Change largest undimmed detent"
          onPress={() => {
            const newDetentLevel = nextDetentLevel(largestUndimmedDetent);
            setLargestUndimmedDetent(newDetentLevel);
            navigation.setOptions({
              sheetLargestUndimmedDetent: newDetentLevel,
            });
          }}
        />
        <Text>largestUndimmedDetent: {largestUndimmedDetent}</Text>
        <Button
          title="Toggle sheetExpandsWhenScrolledToEdge"
          onPress={() => {
            setShouldExpand(!shouldExpand);
            navigation.setOptions({
              sheetExpandsWhenScrolledToEdge: !shouldExpand,
            });
          }}
        />
        <Text>
          sheetExpandsWhenScrolledToEdge: {shouldExpand ? 'true' : 'false'}
        </Text>
        <Button
          title="Toggle grabber visibility"
          onPress={() => {
            setIsGrabberVisible(!isGrabberVisible);
            navigation.setOptions({
              sheetGrabberVisible: !isGrabberVisible,
            });
          }}
        />
      </View>
      <TouchableOpacity
        style={{ backgroundColor: 'goldenrod' }}
        onPress={() => console.log('GH Button clicked')}>
        <Text>GH BUTTON</Text>
      </TouchableOpacity>
      {isAdditionalContentVisible && (
        <View style={{ backgroundColor: 'pink' }}>
          <Text>Additional content</Text>
        </View>
      )}
    </View>
  );
}
