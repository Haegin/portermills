import React, { ReactNode } from 'react'
import Link from 'next/link'
import styled from 'styled-components'

const Container = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0 1rem;

  h4 {
    text-transform: uppercase;
    margin-bottom: 2rem;
  }

  p {
    text-align: center;
  }
`

const Icon = styled.div`
  width: 100px;
  height: 100px;
  background-color: ${p => p.theme.colors.blue};
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: ${p => p.theme.colors.beige};
`

interface Props {
  icon: string
  title: string
  className?: string
  children: ReactNode
}

const iconStack = ({ title, icon, className, children }: Props) => {
  return (
    <Container className={className}>
      <Icon>{icon}</Icon>
      <h4>{title}</h4>
      {children}
    </Container>
  )
}

export default iconStack
