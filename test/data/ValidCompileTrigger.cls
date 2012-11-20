Trigger t on Account (after insert) {
  for (Account a : Trigger.new) {
    // Do something
  }
}