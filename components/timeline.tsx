import React, { ReactNode } from 'react'
import styled from 'styled-components'

const YearContainer = styled.section`
  display: flex;
  img {
    flex: 1 1 0;
    width: calc(50% - 4.125rem);
    max-height: 300px;
    object-fit: cover;
  }
  div {
    border-right: 0.25rem dashed ${p => p.theme.colors.primaryText};
    margin: 0 4rem;
    width: 0px;
    flex-basis: 0;
  }
  aside {
    flex: 1 1 0;
    width: calc(50% - 4.125rem);
    h5 {
      margin-bottom: 2rem;
    }
  }
`

interface YearProps {
  image: string
  children: ReactNode
  className?: string
}

export const Year = ({ children, image, className }: YearProps) => (
  <YearContainer className={className}>
    <img src={image} />
    <div />
    <aside>{children}</aside>
  </YearContainer>
)

const Timeline = styled.article`
  display: flex;
  flex-direction: column;

  & > :nth-child(2n) {
    flex-direction: row-reverse;
  }
`

export default Timeline
