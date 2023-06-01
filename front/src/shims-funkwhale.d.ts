export declare global {
  interface Window {
    funkwhale: {
      registerSoundImplementation: (implementation: SoundImplementation) => void
    }
  }

  type Constructor<T> = {
    new(...args: any[]): T;
    readonly prototype: T;
  }
}
