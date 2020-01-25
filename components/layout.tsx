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

  h3 {
    padding: 0;
    margin: 0;
    margin-bottom: 4rem;
  }

  & section {
    margin: 0 100rem;
    padding: 6rem 0;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  & > section > div {
    display: flex;
    flex-direction: row;
  }

  & button {
    margin-top: 4rem;
    margin-bottom: 0;
    border-color: ${p => p.theme.colors.beige};
    color: ${p => p.theme.colors.beige};
  }
`

export { Content, Bar }
