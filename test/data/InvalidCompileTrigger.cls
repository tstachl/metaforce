Trigger t on Account (afterr insert) {
  for (Account a : Trigger.new) {
    // Do something
  }
}