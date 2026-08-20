import { BackgroundImage, MantineProvider } from '@mantine/core';
import React from 'react';
import theme from '../theme';
import { isEnvBrowser } from '../utils/misc';
import { UI } from './UI/main';

const App: React.FC = () => {
  return (
    <MantineProvider theme={theme} defaultColorScheme="dark">
      <Wrapper>
        <UI />
      </Wrapper>
    </MantineProvider>
  );
};

export default App;

function Wrapper({ children }: { children: React.ReactNode }) {
  return isEnvBrowser() ? (
    <BackgroundImage
      w="100vw"
      h="100vh"
      style={{ overflow: 'hidden' }}
      src="https://i.imgur.com/kiK65kg.jpeg"
    >
      {children}
    </BackgroundImage>
  ) : (
    <>{children}</>
  );
}
