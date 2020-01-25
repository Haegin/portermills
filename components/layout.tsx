import styled from 'styled-components'

const Content = styled.div`
  width: 960px;
  margin: auto;
`

const Bar = styled.div`
  display: flex;
  flex-direction: column;
  margin: 8rem -100rem;
  background-color: ${p => p.theme.colors.orange};
  color: ${p => p.theme.colors.beige};

  & section {
    margin: 0 100rem;
    padding: 4rem 0;
  }

  & button {
    border-color: ${p => p.theme.colors.beige};
    color: ${p => p.theme.colors.beige};
  }
`

export { Content, Bar }
