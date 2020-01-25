import React, { ReactNode } from 'react'
import styled from 'styled-components'

import _ImageBlock from './imageBlock'

const ImageBlock = styled(_ImageBlock)

const Container = styled.div`
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  margin: 8rem 0;
`

interface Props {
  children: ReactNode
}

const threeUp = ({ children }: Props) => {
  return <Container>{children}</Container>
}

export default threeUp
