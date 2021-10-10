// eslint-disable-next-line no-unused-vars
import React from 'react'
import pdf from '@react-pdf/renderer'
import dayjs from '../../../../../common/helpers/dayjs.js'

const { Text, View } = pdf

const fontSize = 9

const columnStyles = {
  flexGrow: 0,
  flexShrink: 0,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'stretch',
  marginTop: (-fontSize / 2.0 - 1) + 'pt',
  marginBottom: (fontSize / 2.0 + 1) + 'pt'
}
const rowStyles = {
  paddingHorizontal: '2pt',
  fontSize: fontSize + 'pt',
  flexBasis: 1
}

function TimeColumn ({ times, styles }) {
  return <View style={{ ...styles, ...columnStyles }}>
    {times.map(([time, weight]) => {
      return <Text key={time} style={{ flexGrow: weight, ...rowStyles }}>{(time !== times[0][0]) ? dayjs().hour(time).minute(0).second(0).format('LT') : ' '}</Text>
    })}
  </View>
}

export default TimeColumn
